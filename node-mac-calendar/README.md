[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](https://lbesson.mit-license.org/)
 [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com) [![Actions Status](https://github.com/haroonmoh/node-mac-calendar/workflows/Test/badge.svg)](https://github.com/haroonmoh/node-mac-calendar/actions)

# node-mac-calendar

## Description

```js
$ npm i node-mac-calendar
```

This Native Node Module allows you to create, read, update, and delete calendar events from users' calendar databases on macOS.

All methods invoking the [EKEventStore](https://developer.apple.com/documentation/eventkit/ekeventstore) will require authorization, which you can request from users with the `requestAccess` method. You can verify authorization status with `calendar.getAuthStatus()` as outlined below.

In your app, you should put the reason you're requesting to manipulate user's calendar database in your `Info.plist` like so:

```
<key>NSCalendarsUsageDescription</key>
<string>Your reason for wanting to access the Calendar store</string>
```

If you're using macOS 12.3 or newer, you'll need to ensure you have Python installed on your system, as macOS does not bundle it anymore.

## API

### `calendar.requestAccess()`

Returns `Promise<String>` - Can be one of 'Denied', 'Authorized'.

Requests access to the [EKEventStore](https://developer.apple.com/documentation/eventkit/ekeventstore) via a dialog presented to the user.

If the user has previously denied the request, this method will open the Calendar pane within the Privacy section of System Preferences.

*Note that access permission request prompts will not appear when `requestAccess()` is invoked in embedded terminals such as those found in Visual Studio Code. Run your code from an external terminal such as Terminal.app instead.*

### `calendar.getAuthStatus()`

Returns `String` - Can be one of 'Not Determined', 'Denied', 'Authorized', or 'Restricted'.

Checks the authorization status of the application to access the central Calendar store on macOS.

Return Value Descriptions: 
* 'Not Determined' - The user has not yet made a choice regarding whether the application may access calendar data.
* 'Not Authorized' - The application is not authorized to access calendar data. The user cannot change this application's status, possibly due to active restrictions such as parental controls being in place.
* 'Denied' - The user explicitly denied access to calendar data for the application.
* 'Authorized' - The application is authorized to access calendar data.

Example Usage:

```js
const authStatus = calendar.getAuthStatus()

console.log(`Authorization access to calendar is: ${authStatus}`)
/* prints one of:
'Not Determined'
'Denied',
'Authorized'
'Restricted'
*/
```

### `calendar.getAllEvents([options])` (Placeholder)

* `options` Object (optional) - Options for fetching events (e.g., date range).

Returns `Array<Object>` - Returns an array of event objects.

(Details of event object structure to be defined based on EventKit.)

This method will return an empty array (`[]`) if access to Calendar has not been granted.

Example Usage: (Placeholder)

```js
const allEvents = calendar.getAllEvents();
console.log(allEvents[0]);
```

### `calendar.getEventsByName(name[, options])` (Placeholder)

* `name` String (required) - The title or part of the title of an event.
* `options` Object (optional) - Additional filtering options.

Returns `Array<Object>` - Returns an array of event objects matching the name.

(Details of event object structure to be defined based on EventKit.)

This method will return an empty array (`[]`) if access to Calendar has not been granted.

Example Usage: (Placeholder)

```js
const events = calendar.getEventsByName('Meeting');
console.log(events);
```

### `calendar.addNewEvent(eventData)` (Placeholder)

* `eventData` Object (required) - Data for the new event (e.g., title, startDate, endDate).

Returns `Boolean` - whether the event was created successfully.

Creates and saves a new event to the user's calendar database.

This method will return `false` if access to Calendar has not been granted.

Example Usage: (Placeholder)

```js
const success = calendar.addNewEvent({
  title: 'Team Meeting',
  startDate: new Date(),
  // ... other event properties
});
console.log(`New event was ${success ? 'saved' : 'not saved'}.`)
```

### `calendar.deleteEvent(eventIdentifier)` (Placeholder)

* `eventIdentifier` String (required) - The unique identifier of the event to delete.

Returns `Boolean` - whether the event was deleted successfully.

Deletes an event from the user's calendar database.

This method will return `false` if access to Calendar has not been granted.

Example Usage: (Placeholder)

```js
const eventId = 'some-event-id';
const deleted = calendar.deleteEvent(eventId);
console.log(`Event ${eventId} was ${deleted ? 'deleted' : 'not deleted'}.`)
```

### `calendar.updateEvent(eventData)` (Placeholder)

* `eventData` Object (required) - Updated data for the event (must include identifier).

Returns `Boolean` - whether the event was updated successfully.

Updates an event in the user's calendar database.

This method will return `false` if access to Calendar has not been granted.

Example Usage: (Placeholder)

```js
const success = calendar.updateEvent({
  identifier: 'some-event-id',
  title: 'Updated Team Meeting Title',
  // ... other updated event properties
});
console.log(`Event was ${success ? 'updated' : 'not updated'}.`)
```

## Development

To build this module:

```bash
$ npm install
$ npm run build
```

To run tests:

```bash
$ npm test
```

## Contributing

PRs are welcome! Please ensure that your code adheres to the existing style and that tests pass.

## License

[MIT](LICENSE)
