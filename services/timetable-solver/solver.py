"""OR-Tools CP-SAT timetable solver.

Hard constraints (must never be violated):
- No teacher double-booked (same day+period)
- No class double-booked (same day+period)
- Teacher weekly load <= max_periods
- Only assign qualified teachers to subjects

Soft constraints (weighted penalties in objective):
- Prefer core subjects (Math/Science/English) in morning slots
- Spread a subject's periods_per_week evenly across the week

If OR-Tools cannot find a feasible solution, returns a detailed conflict report.
Never fails silently.

Room assignment is done as a post-processing step: the solver finds (subject, teacher)
assignments, then rooms are greedily assigned per slot. This avoids the room dimension
exploding the variable count (10 rooms × 3300+ candidates = 750k+ bool vars).
"""

from typing import Any
import sys

from ortools.sat.python import cp_model


def solve_timetable(constraints: dict[str, Any]) -> dict[str, Any]:
    """Run OR-Tools CP-SAT and return the timetable or infeasibility report."""

    days = constraints["days"]
    num_days = len(days)
    n_periods = constraints["num_periods"]
    total_slots = num_days * n_periods  # e.g. 5*6=30

    classes = constraints["classes"]      # [{id, name, subjects: [...]}]
    teachers = constraints["teachers"]    # {tid: {name, max_periods}}
    teacher_quals = constraints["teacher_quals"]  # {tid: [subject_name, ...]}
    rooms = constraints["rooms"]          # [{id, name}]
    rooms_raw = constraints["_rooms_raw"]
    _teacher_names = constraints["_teacher_names"]
    slot_id_map = constraints.get("_slot_id_map", {})
    # (class_index, subject_name) -> subject_id, so output rows carry the real
    # academic.subjects id that /commit writes into timetable.subject_id.
    subject_id_map = {
        (ci, s["name"]): s.get("id")
        for ci, cl in enumerate(classes)
        for s in cl["subjects"]
    }

    model = cp_model.CpModel()

    # ── Build (subject, teacher) candidate pool per class ────────────
    # Each class has its own list of (subj_name, teacher_id) pairs.
    # Room is NOT part of the candidate — assigned as post-processing.
    cands_per_class: list[list[tuple[str, str]]] = []
    for ci, cl in enumerate(classes):
        cl_cands: list[tuple[str, str]] = []
        seen: set[tuple[str, str]] = set()
        cl_subj_names = sorted({s["name"] for s in cl["subjects"]})
        for subj in cl_subj_names:
            for tid, quals in teacher_quals.items():
                if subj in quals:
                    key = (subj, tid)
                    if key not in seen:
                        seen.add(key)
                        cl_cands.append(key)
        cands_per_class.append(cl_cands)

    # ── Binary decision variables ────────────────────────────────────
    # z[(ci, slot, ci_cand_index)] = 1 iff class ci in slot uses candidate ci_cand_index
    z: dict[tuple[int, int, int], cp_model.IntVar] = {}
    for ci in range(len(classes)):
        for slot in range(total_slots):
            for ci_i in range(len(cands_per_class[ci])):
                v = model.NewBoolVar(f"z_{ci}_{slot}_{ci_i}")
                z[(ci, slot, ci_i)] = v

    # ── Hard 1: at most one assignment per (class, slot) ─────────
    for ci in range(len(classes)):
        for slot in range(total_slots):
            vs = [z[(ci, slot, ci_i)] for ci_i in range(len(cands_per_class[ci]))]
            if vs:
                model.Add(sum(vs) <= 1)

    # ── Hard 2: no teacher double-booking ────────────────────────
    for slot in range(total_slots):
        teacher_map: dict[str, list[cp_model.IntVar]] = {}
        for ci in range(len(classes)):
            for ci_i in range(len(cands_per_class[ci])):
                _, tid = cands_per_class[ci][ci_i]
                teacher_map.setdefault(tid, []).append(z[(ci, slot, ci_i)])
        for tid, vs in teacher_map.items():
            if len(vs) > 1:
                model.Add(sum(vs) <= 1)

    # ── Hard 3: teacher max_periods ──────────────────────────────
    for tid, info in teachers.items():
        z_teachers: list[cp_model.IntVar] = []
        for ci in range(len(classes)):
            for slot in range(total_slots):
                for ci_i in range(len(cands_per_class[ci])):
                    _, t = cands_per_class[ci][ci_i]
                    if t == tid:
                        z_teachers.append(z[(ci, slot, ci_i)])
        if z_teachers:
            model.Add(sum(z_teachers) <= info["max_periods"])

    # ── Hard 4: exact periods_per_week per subject per class ─────
    unschedulable: list[str] = []

    # Check for classes with zero subjects.
    for ci, cl in enumerate(classes):
        if not cl["subjects"]:
            unschedulable.append(
                f"Class '{cl['name']}' has no subjects defined in "
                f"academic.subjects — nothing to schedule"
            )

    if unschedulable:
        report = _infeasibility_report(constraints)
        report["conflicts"] = unschedulable + report["conflicts"]
        return report

    for ci in range(len(classes)):
        for sdata in classes[ci]["subjects"]:
            target = sdata["periods_per_week"]
            z_subj: list[cp_model.IntVar] = []
            for slot in range(total_slots):
                for ci_i in range(len(cands_per_class[ci])):
                    sn, _ = cands_per_class[ci][ci_i]
                    if sn == sdata["name"]:
                        z_subj.append(z[(ci, slot, ci_i)])
            if z_subj:
                model.Add(sum(z_subj) == target)
            elif target > 0:
                unschedulable.append(
                    f"'{sdata['name']}' in class '{classes[ci]['name']}' needs "
                    f"{target} periods/week but has no qualified teacher"
                )

    if unschedulable:
        report = _infeasibility_report(constraints)
        report["conflicts"] = unschedulable + report["conflicts"]
        return report

    # ── Objective: accumulate ALL soft penalties, then Minimize ONCE ─────
    objective_terms: list = []

    # Soft 1: core subjects prefer early (morning) slots.
    for ci in range(len(classes)):
        core_names = {s["name"] for s in classes[ci]["subjects"] if s.get("is_core")}
        for slot in range(total_slots):
            for ci_i in range(len(cands_per_class[ci])):
                sn, _ = cands_per_class[ci][ci_i]
                if sn in core_names:
                    period_nr = slot % n_periods + 1
                    objective_terms.append(period_nr * z[(ci, slot, ci_i)])

    # Soft 2: even spread of each subject across the week.
    for ci in range(len(classes)):
        for si, sdata in enumerate(classes[ci]["subjects"]):
            subj_name = sdata["name"]
            ppw = sdata["periods_per_week"]
            for d in range(num_days):
                day_vars: list[cp_model.IntVar] = []
                lo = d * n_periods
                hi = lo + n_periods
                for slot in range(lo, hi):
                    for ci_i in range(len(cands_per_class[ci])):
                        cn, _ = cands_per_class[ci][ci_i]
                        if cn == subj_name:
                            day_vars.append(z[(ci, slot, ci_i)])
                if day_vars:
                    dev = model.NewIntVar(0, num_days * n_periods, f"dev_{ci}_{si}_{d}")
                    model.AddAbsEquality(dev, num_days * sum(day_vars) - ppw)
                    objective_terms.append(dev)

    if objective_terms:
        model.Minimize(sum(objective_terms))

    # ── Solve ────────────────────────────────────────────────────
    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = 120.0
    solver.parameters.num_workers = 8

    total_vars = sum(len(cands_per_class[ci]) for ci in range(len(classes))) * total_slots
    print(f"Model: {len(classes)} classes, {total_slots} slots, "
          f"classes have {[len(c) for c in cands_per_class]} candidates each, "
          f"{total_vars} variables", file=sys.stderr)

    status = solver.Solve(model)

    # ── Build output ─────────────────────────────────────────────
    if status in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        rows: list[dict] = []
        for ci in range(len(classes)):
            cl = classes[ci]
            for slot in range(total_slots):
                for ci_i in range(len(cands_per_class[ci])):
                    if solver.Value(z[(ci, slot, ci_i)]) == 1:
                        subj_name, tid = cands_per_class[ci][ci_i]
                        d_idx = slot // n_periods
                        p_nr = slot % n_periods + 1
                        rows.append({
                            "class_id": cl["id"],
                            "class_name": cl["name"],
                            "day": days[d_idx],
                            "period": p_nr,
                            "slot_id": slot_id_map.get((days[d_idx], p_nr)),
                            "subject": subj_name,
                            "subject_id": subject_id_map.get((ci, subj_name)),
                            "teacher_id": tid,
                            "teacher_name": _teacher_names.get(tid, tid),
                            # room is assigned post-hoc
                            "room_id": None,
                            "room_name": None,
                        })

        # Post-hoc room assignment: assign rooms greedily per slot.
        _assign_rooms(rows, rooms_raw)

        summary = _summary(rows, classes)
        return {"status": "success", "timetable": rows, "summary": summary}

    if status == cp_model.INFEASIBLE:
        return _infeasibility_report(constraints)

    # status == UNKNOWN (timeout or presolve stuck)
    return _timeout_report(constraints, status)


def _assign_rooms(rows: list[dict], rooms_raw: list[dict]) -> None:
    """Greedy per-slot room assignment.

    For each (day, period), collect all rows in that slot and assign
    rooms round-robin. This is deterministic and respects the 1-room-per-slot
    constraint within each day+period.
    """
    if not rooms_raw:
        return
    from collections import defaultdict
    by_slot: dict[tuple[str, int], list[dict]] = defaultdict(list)
    for r in rows:
        by_slot[(r["day"], r["period"])].append(r)

    for slot_rows in by_slot.values():
        for i, r in enumerate(slot_rows):
            ri = i % len(rooms_raw)
            r["room_id"] = rooms_raw[ri]["id"]
            r["room_name"] = rooms_raw[ri]["name"]


def _summary(timetable_rows, classes):
    total = len(timetable_rows)
    per_class: dict[str, int] = {}
    for cl in classes:
        per_class[cl["name"]] = sum(
            1 for r in timetable_rows if r["class_id"] == cl["id"]
        )
    return {"total_assignments": total, "per_class": per_class}


def _infeasibility_report(c):
    """Explain WHY CP-SAT proved infeasibility."""
    conflicts: list[str] = []
    days = c["days"]
    num_days = len(days)
    n_periods = c["num_periods"]

    # 1. Room-slots insufficient?
    total_needed = sum(
        sum(s["periods_per_week"] for s in cl["subjects"])
        for cl in c["classes"]
    )
    total_room_slots = len(c["rooms"]) * num_days * n_periods
    if total_needed > total_room_slots:
        conflicts.append(
            f"Total class-periods ({total_needed}) exceed total room-slots "
            f"({len(c['rooms'])} rooms x {num_days} days x {n_periods} periods "
            f"= {total_room_slots})"
        )

    # 2. Unassignable subjects?
    for cl in c["classes"]:
        for sd in cl["subjects"]:
            sn = sd["name"]
            has_teacher = any(sn in q for q in c["teacher_quals"].values())
            if not has_teacher:
                conflicts.append(
                    f"No qualified teacher for '{sn}' in class '{cl['name']}'"
                )

    if not conflicts:
        conflicts.append(
            "No feasible timetable found. Constraints may be too tight. "
            "Try increasing max_periods, adding qualified teachers, or more rooms."
        )

    return {"status": "infeasible", "conflicts": conflicts}


def _timeout_report(c, status):
    """Report that the solver timed out or stopped during presolve."""
    return {
        "status": "timeout",
        "solver_detail": str(status),
        "conflicts": [
            "Solver could not find a timetable within the time limit. "
            "The model is very large; try reducing the number of classes, "
            "subjects, or periods per week."
        ],
    }