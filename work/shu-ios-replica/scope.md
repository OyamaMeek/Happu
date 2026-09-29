# Case Scope

## meta
- case_id: shu-ios-replica
- created: 2026-09-23T15:41:41+08:00
- operator: local
- project_root: /Users/oyamahappa/Documents/GitHub/Happu
- primary_skill: mobile-reverse/SKILL.md
- primary_id: R2
- lead_role: lead
- specialist_roles: []
- hint: iOS reverse local Shu.app for Swift replica
- preset: none

## auth
- status: granted
- basis: written_contract
- evidence_of_auth: User confirmed ownership or authorization and approved the disclosed offline analysis in this task on 2026-09-23; ownership was not independently verified.
- MUST NOT proceed if status != granted

## in_scope
- assets:
  - /Users/oyamahappa/Documents/GitHub/Happu/Payload/Shu.app/Shu
  - /Users/oyamahappa/Documents/GitHub/Happu/Payload/Shu.app
- surfaces: [mobile, binary, bundled_resources]
- activities: [offline_static_analysis, swift_replica, report]

## out_of_scope
- assets: []
- activities: [dos, phishing_real_users, unrestricted_exfil]

## network_profile
- mode: offline
- notes: |
    offline | lab_only | authorized_target_only | unrestricted_lab
    Change mode only after auth.status = granted.
    Presets: offline-sample | ctf-public | own-system

## deliverables
- report: true
- field_journal: true
- diagrams: true
- timeline: true

## constraints
- timebox: {}
- stealth: low
- data_handling: anonymize

## signoff
- ready_for_act: true
- checklist:
  - [x] auth.status = granted
  - [x] in_scope.assets non-empty OR offline sample path set
  - [x] network_profile.mode chosen
  - [x] out_of_scope reviewed
  - [x] roles assigned: lead

## ops_refs
- skills/ops/scope-contract.md
- skills/ops/evidence-finding-path.md
- skills/ops/role-map.md
- skills/ops/timeline-workitem.md
- skills/ops/IDENTITY.md
