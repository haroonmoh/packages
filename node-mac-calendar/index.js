const calendar = require('bindings')('calendar.node');

function getAllEvents(startDate, endDate) {
  if (!(startDate instanceof Date) && typeof startDate !== 'string') {
    throw new TypeError('startDate must be a Date object or an ISO 8601 string');
  }
  if (!(endDate instanceof Date) && typeof endDate !== 'string') {
    throw new TypeError('endDate must be a Date object or an ISO 8601 string');
  }

  const startStr = (startDate instanceof Date) ? startDate.toISOString() : startDate;
  const endStr = (endDate instanceof Date) ? endDate.toISOString() : endDate;

  return calendar.getAllEvents.call(this, startStr, endStr);
}

function getEventsByName(name, startDate, endDate) {
  if (typeof name !== 'string') {
    throw new TypeError('name must be a string');
  }
  if (!(startDate instanceof Date) && typeof startDate !== 'string') {
    throw new TypeError('startDate must be a Date object or an ISO 8601 string');
  }
  if (!(endDate instanceof Date) && typeof endDate !== 'string') {
    throw new TypeError('endDate must be a Date object or an ISO 8601 string');
  }

  const startStr = (startDate instanceof Date) ? startDate.toISOString() : startDate;
  const endStr = (endDate instanceof Date) ? endDate.toISOString() : endDate;

  return calendar.getEventsByName.call(this, name, startStr, endStr);
}

function addNewEvent(eventData) {
  if (!eventData || typeof eventData !== 'object') {
    throw new TypeError('eventData must be an object');
  }
  if (typeof eventData.title !== 'string' || eventData.title.trim() === '') {
    throw new TypeError('eventData.title must be a non-empty string');
  }
  if (!(eventData.startDate instanceof Date) && typeof eventData.startDate !== 'string') {
    throw new TypeError('eventData.startDate must be a Date object or an ISO 8601 string');
  }
  if (!(eventData.endDate instanceof Date) && typeof eventData.endDate !== 'string') {
    throw new TypeError('eventData.endDate must be a Date object or an ISO 8601 string');
  }

  const dataToSend = {
    ...eventData,
    startDate: (eventData.startDate instanceof Date) ? eventData.startDate.toISOString() : eventData.startDate,
    endDate: (eventData.endDate instanceof Date) ? eventData.endDate.toISOString() : eventData.endDate,
  };

  return calendar.addNewEvent.call(this, dataToSend);
}

function deleteEvent(eventIdentifier) {
  if (typeof eventIdentifier !== 'string' || eventIdentifier.trim() === '') {
    throw new TypeError('eventIdentifier must be a non-empty string');
  }
  return calendar.deleteEvent.call(this, eventIdentifier);
}

function updateEvent(eventData) {
  if (!eventData || typeof eventData !== 'object') {
    throw new TypeError('eventData must be an object');
  }
  if (typeof eventData.identifier !== 'string' || eventData.identifier.trim() === '') {
    throw new TypeError('eventData.identifier must be a non-empty string');
  }

  // Prepare data, ensuring dates are ISO strings if they are Date objects
  const dataToSend = { ...eventData };
  if (eventData.startDate instanceof Date) {
    dataToSend.startDate = eventData.startDate.toISOString();
  }
  if (eventData.endDate instanceof Date) {
    dataToSend.endDate = eventData.endDate.toISOString();
  }
  
  return calendar.updateEvent.call(this, dataToSend);
}

// Placeholder for other calendar functions

module.exports = {
  requestAccess: calendar.requestAccess,
  getAuthStatus: calendar.getAuthStatus,
  getAllEvents,
  getEventsByName,
  addNewEvent,
  deleteEvent,
  updateEvent,
};
