# server-private response fixtures

Public, unauthenticated responses captured on 2026-10-16:

- `subject.json`: https://next.bgm.tv/p1/subjects/8
- `episodes.json`: https://next.bgm.tv/p1/subjects/8/episodes?limit=2
- `characters.json`: https://next.bgm.tv/p1/subjects/8/characters?limit=1
- `staff.json`: https://next.bgm.tv/p1/subjects/8/staffs/persons?limit=1
- `calendar.json`: one Monday entry from https://next.bgm.tv/p1/calendar

The tests add synthetic collection fields and change chapter numbers to cover
private progress, timestamps, specials, pagination and season-relative numbers.
No credentials or authenticated user data are included.

Contract: https://github.com/bangumi/server-private/blob/master/openapi.json
