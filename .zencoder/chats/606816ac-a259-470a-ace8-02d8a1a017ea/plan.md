# Spec and build
2→
3→## Agent Instructions
4→
5→Ask the user questions when anything is unclear or needs their input. This includes:
6→
7→- Ambiguous or incomplete requirements
8→- Technical decisions that affect architecture or user experience
9→- Trade-offs that require business context
10→
11→Do not make assumptions on important decisions — get clarification first.
12→
13→---
14→
15→## Workflow Steps
16→
17→### [x] Step: Technical Specification
18→
19→Assess the task's difficulty, as underestimating it leads to poor outcomes.
20→
21→- easy: Straightforward implementation, trivial bug fix or feature
22→- medium: Moderate complexity, some edge cases or caveats to consider
23→- hard: Complex logic, many caveats, architectural considerations, or high-risk changes
24→
25→Create a technical specification for the task that is appropriate for the complexity level:
26→
27→- Review the existing codebase architecture and identify reusable components.
28→- Define the implementation approach based on established patterns in the project.
29→- Identify all source code files that will be created or modified.
30→- Define any necessary data model, API, or interface changes.
31→- Describe verification steps using the project's test and lint commands.
32→
33→Save the output to `c:\Users\Ultra-Tech\Desktop\taxi_app\.zencoder\chats\606816ac-a259-470a-ace8-02d8a1a017ea/spec.md` with:
34→
35→- Technical context (language, dependencies)
36→- Implementation approach
37→- Source code structure changes
38→- Data model / API / interface changes
39→- Verification approach
40→
41→If the task is complex enough, create a detailed implementation plan based on `c:\Users\Ultra-Tech\Desktop\taxi_app\.zencoder\chats\606816ac-a259-470a-ace8-02d8a1a017ea/spec.md`:
42→
43→- Break down the work into concrete tasks (incrementable, testable milestones)
44→- Each task should reference relevant contracts and include verification steps
45→- Replace the Implementation step below with the planned tasks
46→
47→Rule of thumb for step size: each step should represent a coherent unit of work (e.g., implement a component, add an API endpoint, write tests for a module). Avoid steps that are too granular (single function).
48→
49→Save to `c:\Users\Ultra-Tech\Desktop\taxi_app\.zencoder\chats\606816ac-a259-470a-ace8-02d8a1a017ea/plan.md`. If the feature is trivial and doesn't warrant this breakdown, keep the Implementation step below as is.
50→
51→**Stop here.** Present the specification (and plan, if created) to the user and wait for their confirmation before proceeding.
52→
53→---
54→
55→### [x] Step: Update Android Manifest and iOS Info.plist
56→
57→Add required `<queries>` to `.\android\app\src\main\AndroidManifest.xml` and `LSApplicationQueriesSchemes` to `.\ios\Runner\Info.plist` to enable package visibility and custom URL schemes.
58→
59→---
60→
61→### [x] Step: Refactor Homepage Marker Tap Logic
62→
63→Update `_openEmergencyNavigation` in `.\lib\home_page.dart` to attempt acquiring location if `currentPosition` is null instead of returning early.
64→
65→---
66→
67→### [x] Step: Fix Google Maps URI and Verification
68→
69→Fix the `google.navigation` URI format in `.\lib\emergency_navigation_page.dart` using `Uri.parse`. Run `flutter analyze` and `flutter build apk --debug` to verify changes.
70→
71→---
72→
73→### [x] Step: Final Report
74→
75→After completion, write a report to `c:\Users\Ultra-Tech\Desktop\taxi_app\.zencoder\chats\606816ac-a259-470a-ace8-02d8a1a017ea/report.md`.
