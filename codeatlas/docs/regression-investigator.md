# Regression Investigator

> **"Understand before you change."**
> CodeAtlas Regression Investigator answers: *"Why did this change cause a regression?"* and *"What existing behavior is at risk because of this change?"*

---

## 1. Problem Statement

When modifying code, developers face subtle regressions that pass basic syntax checks but break edge cases, business calculations, downstream UI formatting, or unwritten contracts.

Traditional CI/CD pipelines only catch bugs if pre-existing tests specifically assert the broken edge case. If no test covers a boundary condition (e.g. `totalLogs == 0` in an adherence formula), the regression escapes to production undetected.

**Regression Investigator** analyzes **Git diffs**, **changed code lines**, and the **static repository knowledge graph** to discover:
- Modified boundary conditions and conditional edge-cases
- Changed metric formulas and arithmetic calculations
- Downstream callers and UI screens consuming altered values
- Test coverage gaps and missing edge-case validation
- Verifiable ground-truth source evidence
- Concrete suggested validation test scenarios

---

## 2. Developer Workflow

```
┌────────────────────────────────────────────────────────┐
│ 1. Developer provides Git diff, changed file, or query │
│    e.g. Paste unified diff of medicine_service.dart    │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 2. Diff Parsing & Symbol Intersection                  │
│    - Extracts modified files and line number hunks     │
│    - Intersects line ranges with indexed symbol spans  │
│    - Identifies exact modified functions and methods   │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 3. Static Regression Signal Detection                  │
│    - Edge-cases (zero counts, nulls, empty collections)│
│    - Calculations (formulas, arithmetic, rates)        │
│    - State mutations (status flags, transitions)       │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 4. Knowledge Graph Traversal                           │
│    - Discovers affected callers and dependents         │
│    - Identifies downstream UI screens & alert thresholds│
│    - Maps existing test suites and coverage gaps       │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 5. Risk Synthesis & Concrete Validation Recommendations│
│    - Ranks risks by severity (HIGH, MEDIUM, LOW)       │
│    - Provides concrete, runnable test specifications   │
│    - Displays verifiable source code evidence          │
└─────────────────────────┬──────────────────────────────┘
```

---

## 3. Regression Risk Categories

| Category | Description | Severity Rules |
| :--- | :--- | :--- |
| `EDGE_CASE` | Boundary conditions, zero comparisons (`== 0`, `<= 0`), null checks, empty collection fallbacks. | **HIGH** if component has downstream callers/screens; **MEDIUM** otherwise. |
| `BUSINESS_LOGIC` | Formula changes, arithmetic operations, rounding, clamping, rate calculations. | **HIGH** if metric is rendered on UI or used by callers; **MEDIUM** otherwise. |
| `UI` | Presentation components, alert thresholds, and score badges depending on changed metrics. | **HIGH** if multiple screens/dashboards consume the metric. |
| `TEST_COVERAGE` | Test suite analysis identifying unverified edge cases or missing automated tests. | **HIGH** if no tests exist; **MEDIUM** if tests exist but lack edge-case coverage. |
| `DATA` | State mutations to database collections that have downstream readers in reports/UI. | **HIGH** if persistent collections are affected. |
| `STATE` | Status enum and state transition logic changes. | **MEDIUM** to **HIGH**. |
| `API` | Changes to method signatures, parameter types, or REST/gRPC contracts. | **HIGH** if multiple consumers invoke the API. |

---

## 4. Diff Parsing & Symbol Intersection

Unified diffs (`diff --git`, standard patches, or manual hunk inputs) are parsed into structured hunk intervals:
```
@@ -580,6 +580,8 @@
```
The line span $(580, 587)$ is intersected against all symbols in the repository file:
$$\text{Symbol Span: } [\text{line\_start}, \text{line\_end}] \cap [\text{new\_start}, \text{new\_end}] \neq \emptyset$$
This pinpoints the exact method modified (e.g. `MedicineService.getRealStats`) without requiring full re-indexing.

---

## 5. CareSync Adherence Demonstration

### Scenario: Changing Medicine Adherence Calculation

Consider a developer modifying `lib/services/medicine_service.dart`:
```dart
@@ -580,6 +580,8 @@ class MedicineService {
       int adherence = 0;
       if (totalLogs > 0) {
         final takenCount = allLogs.where((l) => l['status'] == 'taken').length;
-        adherence = ((takenCount / totalLogs) * 100).round().clamp(0, 100);
+        adherence = ((takenCount / totalLogs) * 100).round();
       } else if (inventory.isNotEmpty) {
-        adherence = 100;
+        adherence = 0;
       }
```

### Discovered Risks & Ground Truth Evidence

1. **`EDGE_CASE` Risk (HIGH)**:
   - **Finding**: Conditional branch `totalLogs > 0` vs fallback `else if (inventory.isNotEmpty)` altered from `100` to `0`.
   - **Reason**: When a new patient has inventory items but zero logged doses (`totalLogs == 0`), adherence is set to 0% instead of the original 100% baseline.
   - **Evidence**: `lib/services/medicine_service.dart:584` (`else if (inventory.isNotEmpty)`)
   - **Suggested Test**: `"Assert MedicineService.getRealStats when totalLogs == 0 and inventory.isNotEmpty, verifying whether 100% or 0% adherence is expected."`

2. **`BUSINESS_LOGIC` Risk (HIGH)**:
   - **Finding**: Metric formula `((takenCount / totalLogs) * 100)` clamping removed.
   - **Reason**: Downstream callers and UI screens depending on adherence rate may receive unconstrained values.

3. **`UI` Risk (HIGH)**:
   - **Finding**: Downstream screens ([reports_screen.dart](file:///c:/Users/Sahil/Downloads/CodeAtlas/caresync_source/lib/screens/reports_screen.dart), [alerts_screen.dart](file:///c:/Users/Sahil/Downloads/CodeAtlas/caresync_source/lib/screens/alerts_screen.dart), [patient_dashboard_screen.dart](file:///c:/Users/Sahil/Downloads/CodeAtlas/caresync_source/lib/screens/caregiver/patient_dashboard_screen.dart)) consume `adherence_rate` with a $\ge 80\%$ threshold for alert coloring (green vs red/orange).
   - **Reason**: Shifting adherence for zero-log patients from 100% to 0% triggers false-positive "Low adherence detected" warnings on initial onboarding.

4. **`TEST_COVERAGE` Risk (MEDIUM)**:
   - **Finding**: Existing test suite [test_models_services.dart](file:///c:/Users/Sahil/Downloads/CodeAtlas/caresync_source/test_models_services.dart) tests non-zero doses (`taken / total`), but lacks coverage for the `totalLogs == 0` boundary condition.
   - **Suggested Test**: `"Add dedicated test case in test_models_services.dart asserting getRealStats behavior on empty dose log collections."`

---

## 6. Verifiable Evidence & Confidence Model

Every regression risk is backed by verifiable ground-truth evidence:
- **`CONFIRMED`**: Directly proven by source line snippets and static AST relationships.
- **`INFERRED`**: Associated through multi-hop knowledge graph propagation.
- **`UNKNOWN`**: Flagged when dynamic runtime verification is required.

---

## 7. Limitations

- **Runtime Dynamic States**: Pure runtime state combinations that depend on external live databases without static references require test execution.
- **Unexecuted Code**: Regression Investigator highlights risks and generates suggested test scenarios; it does not execute repository test code or auto-modify files.
