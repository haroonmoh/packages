// test-script.js
const calendar = require('./index.js'); // Assuming test-script.js is in the same directory as index.js

async function runCalendarTests() {
    console.log("Starting node-mac-calendar tests...");

    try {
        // 1. Check initial authorization status
        const initialAuthStatus = calendar.getAuthStatus();
        console.log("Initial Calendar Authorization Status:", initialAuthStatus);

        // 2. Request calendar access
        console.log("\nRequesting calendar access...");
        const accessStatus = await calendar.requestAccess();
        console.log("Access Status after request:", accessStatus);

        // If not authorized, explain and stop tests that require authorization
        if (accessStatus !== "Authorized") {
            console.error("\nCalendar access not authorized. Please grant access in System Settings > Privacy & Security > Calendars and try again.");
            console.log("Skipping further tests that require calendar authorization.");
            return;
        }

        console.log("\n--- Calendar access authorized. Proceeding with event manipulation tests ---");

        // Prepare dates for testing
        const now = new Date();
        const startDate = new Date(now);
        startDate.setDate(now.getDate() + 1); // Tomorrow
        startDate.setHours(10, 0, 0, 0); // 10:00 AM

        const endDate = new Date(startDate);
        endDate.setHours(startDate.getHours() + 1); // 1 hour duration

        const eventTitle = "My Test Event - " + Date.now(); // Unique title
        let createdEventIdentifier = null;

        // 3. Add a new event
        console.log(`\n--- Testing addNewEvent ---`);
        const newEventData = {
            title: eventTitle,
            startDate: startDate, // Using Date object
            endDate: endDate,     // Using Date object
            // isAllDay: false, // Example: can add more properties later
            // location: "Test Location",
            // notes: "Some notes about this test event."
        };
        const addSuccess = calendar.addNewEvent(newEventData);
        console.log("addNewEvent success:", addSuccess);

        if (!addSuccess) {
            console.error("Failed to add the new event. Some follow-up tests might fail or be inaccurate.");
        }

        // 4. Get all events (to hopefully see our new event)
        console.log("\n--- Testing getAllEvents ---");
        const rangeStart = new Date(now);
        rangeStart.setHours(0,0,0,0); // From start of today
        const rangeEnd = new Date(now);
        rangeEnd.setDate(now.getDate() + 7); // For the next 7 days

        const allEvents = calendar.getAllEvents(rangeStart.toISOString(), rangeEnd.toISOString());
        console.log(`Found ${allEvents.length} events between ${rangeStart.toLocaleDateString()} and ${rangeEnd.toLocaleDateString()}:`);
        let foundAddedEventInAll = null;
        allEvents.forEach(event => {
            // console.log(`  Title: ${event.title}, Start: ${new Date(event.startDate).toLocaleString()}, ID: ${event.identifier}`);
            if (event.title === eventTitle) {
                foundAddedEventInAll = event;
                createdEventIdentifier = event.identifier;
                console.log(`  [FOUND OUR EVENT] Title: ${event.title}, ID: ${event.identifier}`);
            }
        });
         if (!createdEventIdentifier && allEvents.length > 0) {
            // Fallback: if title match failed (e.g. due to calendar app modifications) and we added successfully,
            // try to find an event that was recently created. This is very heuristic.
            const veryRecentEvent = allEvents.find(e => {
                const eventStartDate = new Date(e.startDate);
                return Math.abs(eventStartDate.getTime() - startDate.getTime()) < 60000; // within 1 minute of our target start
            });
            if (veryRecentEvent) {
                console.log(`Heuristically found a recent event: ${veryRecentEvent.title}, ID: ${veryRecentEvent.identifier}. Using this for update/delete.`);
                createdEventIdentifier = veryRecentEvent.identifier;
            }
        }

        if (!createdEventIdentifier) {
             console.warn("Could not reliably find the added event's identifier. Update and Delete tests will be skipped.");
        }

        // 5. Get events by name
        console.log("\n--- Testing getEventsByName ---");
        const eventsByName = calendar.getEventsByName(eventTitle, rangeStart, rangeEnd); // Using original title and Date objects for range
        console.log(`Found ${eventsByName.length} events with title "${eventTitle}":`);
        eventsByName.forEach(event => {
            console.log(`  Title: ${event.title}, Start: ${new Date(event.startDate).toLocaleString()}, ID: ${event.identifier}`);
            if(event.title === eventTitle && !createdEventIdentifier) createdEventIdentifier = event.identifier; //
        });

        if (!createdEventIdentifier && eventsByName.length > 0 && eventsByName[0].title === eventTitle) {
            createdEventIdentifier = eventsByName[0].identifier;
             console.log(`Identified event ID via getEventsByName: ${createdEventIdentifier}`);
        }

        // Proceed with Update and Delete only if we have an identifier
        if (createdEventIdentifier) {
            // 6. Update the event
            console.log(`\n--- Testing updateEvent for event ID: ${createdEventIdentifier} ---`);
            const updatedEventTitle = "My Updated Test Event - " + Date.now();
            const updatedEventData = {
                identifier: createdEventIdentifier,
                title: updatedEventTitle,
                // startDate: new Date(startDate.getTime() + 60*60*1000), // Optionally change date/time
                // endDate: new Date(endDate.getTime() + 60*60*1000),
                isAllDay: false, // Example of updating/setting another field
            };
            const updateSuccess = calendar.updateEvent(updatedEventData);
            console.log("updateEvent success:", updateSuccess);

            if (updateSuccess) {
                console.log("Event updated. Fetching by new name to verify:");
                 const updatedNamedEvents = calendar.getEventsByName(updatedEventTitle, rangeStart, rangeEnd);
                 if (updatedNamedEvents.some(e => e.identifier === createdEventIdentifier)) {
                    console.log(`  Successfully found updated event: ${updatedNamedEvents.find(e=>e.identifier === createdEventIdentifier).title}`);
                 } else {
                    console.log("  Could not find the updated event by its new name and old ID.");
                 }
            }

            // 7. Delete the event
            console.log(`\n--- Testing deleteEvent for event ID: ${createdEventIdentifier} ---`);
            const deleteSuccess = calendar.deleteEvent(createdEventIdentifier);
            console.log("deleteEvent success:", deleteSuccess);

            if (deleteSuccess) {
                console.log("Event deleted. Fetching all events again to verify it's gone:");
                const eventsAfterDelete = calendar.getAllEvents(rangeStart.toISOString(), rangeEnd.toISOString());
                const foundAfterDelete = eventsAfterDelete.find(e => e.identifier === createdEventIdentifier);
                if (foundAfterDelete) {
                    console.error("  ERROR: Event was found after attempting deletion!");
                } else {
                    console.log("  Event successfully deleted and not found in all events list.");
                }
            }
        } else {
            console.log("\nSkipping update and delete tests as the target event's identifier could not be obtained.");
        }

        console.log("\n--- All calendar tests completed ---");

    } catch (error) {
        console.error("\n--- An error occurred during calendar testing ---");
        console.error(error.message);
        console.error(error.stack);
    }
}

runCalendarTests(); 