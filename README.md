# SBMB is an app infrastructure made for seamless frontend display and alert notifications for baby monitoring via a smart band.

Consider a smart band connected to your baby's hand that will transmit necessary info like locations, decibal levels, movement, etc.

This app is the starting point for an application which will connect to such a smart band, ping it every second, and analyse, display, and alert parents based on disturbing data.

To simulate such a band, a backend server is running which is serving all these values real time and the app connects to that as a demoonstration-only project.

## Features:

- Display data real time, and analyze and give feedback.
- Check location of baby vs set location of home and give alert if baby moves too much far away.
- Notification alerts when app is closed/minimzed so parents always stay informed.

## Technology used:

- baby's data is stored in backend in-memory stored and hosted
- FCM - Firebase messaging services used for notifications when app is shut.
- Firebase firestore to store device tokens and home_lat and home_long coordinates.

## Integrations

- OpenStreetMap map to display baby loction visually
- OpenStreetMap Nominatim - To convert user address input to lat and long values ( geofening )
- Server hosted on Flask and Python.
- Sharedpreferences used to store vital data like parent's and baby's name - to increase user experience.
