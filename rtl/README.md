# RTL

This folder will hold the RTL for the home-inventory chip *logic* (source of truth).

Note: OpenMPW submission requires a Caravel `user_project_wrapper` harness. That harness lives in:
- https://github.com/praneetakapunu/home-inventory-chip-openmpw

Our RTL will be integrated into the harness repo as either:
- a submodule import (current), or
- a vendored snapshot when preparing the final submission bundle.
