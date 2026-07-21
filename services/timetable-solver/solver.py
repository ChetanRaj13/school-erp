"""OR-Tools CP-SAT model.

Hard constraints:
- no teacher double-booked
- no class double-booked
- no room double-booked
- teacher weekly load <= max_load

Soft constraints (as weighted penalties, not hard fails):
- avoid same subject twice a day for one class
- prefer core subjects in morning slots
- even spread of a subject across the week

TODO: implement using ortools.sat.python.cp_model
"""


def solve_timetable(constraints: dict) -> dict:
    raise NotImplementedError
