# Implementation Plan

## Goal: When a taxi presses emergency, notify all taxis with driver details (name, email, taxi matricule, picture)

### Steps:
- [x] 1. Create TODO.md
- [ ] 2. Edit `backend/routes/taxiroutes.js` - Enhance HTTP emergency POST route to fetch & broadcast full driver info (email, taxi_matricule, profile_image)
- [ ] 3. Edit `backend/server.js` - Enhance socket `emergency` handler to query DB for full driver details before broadcasting
- [ ] 4. Edit `lib/home_page.dart` - Update emergency UI to display driver picture, name, email, taxi matricule
- [ ] 5. Restart backend server

