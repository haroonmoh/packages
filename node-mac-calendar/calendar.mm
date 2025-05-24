#include <napi.h>
#import <EventKit/EventKit.h>

// Dummy value to pass into function parameter for ThreadSafeFunction.
Napi::Value NoOp(const Napi::CallbackInfo &info) {
  return info.Env().Undefined();
}

// Function to convert EKAuthorizationStatus to a string
std::string AuthorizationStatusToString(EKAuthorizationStatus status) {
    switch (status) {
        case EKAuthorizationStatusNotDetermined:
            return "Not Determined";
        case EKAuthorizationStatusRestricted:
            return "Restricted";
        case EKAuthorizationStatusDenied:
            return "Denied";
        case EKAuthorizationStatusAuthorized:
            return "Authorized";
        default:
            return "Unknown";
    }
}

// Helper to convert NSDate to ISO8601 string
Napi::String ConvertNSDateToISOString(Napi::Env env, NSDate* date) {
    if (!date) {
        return Napi::String::New(env, "");
    }
    NSISO8601DateFormatter* formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSString* dateString = [formatter stringFromDate:date];
    [formatter release];
    return Napi::String::New(env, [dateString UTF8String]);
}

// Helper to convert ISO8601 string to NSDate
NSDate* ConvertISOStringToNSDate(Napi::Env env, const Napi::String& dateStringNapi) {
    if (dateStringNapi.IsEmpty() || !dateStringNapi.IsString()) {
        return nil;
    }
    std::string dateStr = dateStringNapi.As<Napi::String>().Utf8Value();
    NSISO8601DateFormatter* formatter = [[NSISO8601DateFormatter alloc] init];
    formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
    NSDate* date = [formatter dateFromString:[NSString stringWithUTF8String:dateStr.c_str()]];
    [formatter release];
    return date;
}

// Helper to convert EKEvent to Napi::Object
Napi::Object ConvertEKEventToNapiObject(Napi::Env env, EKEvent* ekEvent) {
    Napi::Object eventObj = Napi::Object::New(env);
    eventObj.Set("identifier", Napi::String::New(env, [ekEvent.eventIdentifier UTF8String]));
    eventObj.Set("title", Napi::String::New(env, [ekEvent.title UTF8String]));
    eventObj.Set("startDate", ConvertNSDateToISOString(env, ekEvent.startDate));
    eventObj.Set("endDate", ConvertNSDateToISOString(env, ekEvent.endDate));
    eventObj.Set("isAllDay", Napi::Boolean::New(env, ekEvent.isAllDay));
    // Add other properties as needed: location, notes, calendar.title, attendees etc.
    return eventObj;
}

Napi::Value GetAuthStatus(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    return Napi::String::New(env, AuthorizationStatusToString(status));
}

Napi::Promise RequestAccess(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    Napi::Promise::Deferred deferred = Napi::Promise::Deferred::New(env);
    
    // Create a ThreadSafeFunction
    Napi::ThreadSafeFunction tsfn = Napi::ThreadSafeFunction::New(
        env,
        Napi::Function::New(env, NoOp), // Dummy JS function
        "RequestAccessCallback",        // Resource name
        0,                              // Max queue size (0 for unlimited)
        1                               // Initial thread count
    );

    EKEventStore* eventStore = [[EKEventStore alloc] init];
    [eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError* _Nullable error) {
        // This callback can be on a different thread.
        // We use the ThreadSafeFunction to call back to the main Node.js thread.
        
        auto callback = [=](Napi::Env cbEnv, Napi::Function jsCallback) {
            if (error) {
                // TODO: Consider how to best propagate the error message itself.
                // For now, resolving with current status string as per original attempt if error occurs.
                // Or, reject the promise properly.
                // deferred.Reject(Napi::Error::New(cbEnv, [error.localizedDescription UTF8String]).Value());
                 EKAuthorizationStatus currentStatusOnError = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
                 deferred.Resolve(Napi::String::New(cbEnv, AuthorizationStatusToString(currentStatusOnError)));
            } else {
                if (granted) {
                    deferred.Resolve(Napi::String::New(cbEnv, "Authorized"));
                } else {
                    EKAuthorizationStatus currentStatus = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
                    deferred.Resolve(Napi::String::New(cbEnv, AuthorizationStatusToString(currentStatus)));
                }
            }
        };
        
        tsfn.BlockingCall(callback); // Pass data if needed, here just triggering the callback
        tsfn.Release(); // Release the TSFN when done
        [eventStore release];
    }];

    return deferred.Promise();
}

Napi::Value GetAllEvents(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 2 || !info[0].IsString() || !info[1].IsString()) {
        Napi::TypeError::New(env, "StartDate and EndDate strings are required.").ThrowAsJavaScriptException();
        return env.Null();
    }

    EKAuthorizationStatus authStatus = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if (authStatus != EKAuthorizationStatusAuthorized) {
        Napi::Error::New(env, "Not authorized to access calendar events. Please request access first.").ThrowAsJavaScriptException();
        return env.Null();
    }

    NSDate* startDate = ConvertISOStringToNSDate(env, info[0].As<Napi::String>());
    NSDate* endDate = ConvertISOStringToNSDate(env, info[1].As<Napi::String>());

    if (!startDate || !endDate) {
        Napi::TypeError::New(env, "Invalid date format. Please use ISO 8601 format.").ThrowAsJavaScriptException();
        return env.Null();
    }

    EKEventStore* eventStore = [[EKEventStore alloc] init];
    NSPredicate* predicate = [eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:nil];
    NSArray<EKEvent*>* ekEvents = [eventStore eventsMatchingPredicate:predicate];

    Napi::Array napiEvents = Napi::Array::New(env, ekEvents.count);
    for (NSUInteger i = 0; i < ekEvents.count; i++) {
        napiEvents[i] = ConvertEKEventToNapiObject(env, ekEvents[i]);
    }

    [eventStore release];
    return napiEvents;
}

Napi::Value GetEventsByName(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 3 || !info[0].IsString() || !info[1].IsString() || !info[2].IsString()) {
        Napi::TypeError::New(env, "Name, StartDate, and EndDate strings are required.").ThrowAsJavaScriptException();
        return env.Null();
    }

    EKAuthorizationStatus authStatus = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if (authStatus != EKAuthorizationStatusAuthorized) {
        Napi::Error::New(env, "Not authorized to access calendar events. Please request access first.").ThrowAsJavaScriptException();
        return env.Null();
    }

    std::string nameQueryStr = info[0].As<Napi::String>().Utf8Value();
    NSString* nameQuery = [NSString stringWithUTF8String:nameQueryStr.c_str()];

    NSDate* startDate = ConvertISOStringToNSDate(env, info[1].As<Napi::String>());
    NSDate* endDate = ConvertISOStringToNSDate(env, info[2].As<Napi::String>());

    if (!startDate || !endDate) {
        Napi::TypeError::New(env, "Invalid date format. Please use ISO 8601 format.").ThrowAsJavaScriptException();
        return env.Null();
    }

    EKEventStore* eventStore = [[EKEventStore alloc] init];
    NSPredicate* predicate = [eventStore predicateForEventsWithStartDate:startDate endDate:endDate calendars:nil];
    NSArray<EKEvent*>* allEventsInRange = [eventStore eventsMatchingPredicate:predicate];
    
    NSMutableArray<EKEvent*>* filteredEvents = [NSMutableArray array];
    for (EKEvent* event in allEventsInRange) {
        if (event.title && [event.title rangeOfString:nameQuery options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [filteredEvents addObject:event];
        }
    }

    Napi::Array napiEvents = Napi::Array::New(env, filteredEvents.count);
    for (NSUInteger i = 0; i < filteredEvents.count; i++) {
        napiEvents[i] = ConvertEKEventToNapiObject(env, filteredEvents[i]);
    }

    [eventStore release];
    return napiEvents;
}

Napi::Value AddNewEvent(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsObject()) {
        Napi::TypeError::New(env, "Event data object is required.").ThrowAsJavaScriptException();
        return env.Null();
    }

    EKAuthorizationStatus authStatus = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if (authStatus != EKAuthorizationStatusAuthorized) {
        Napi::Error::New(env, "Not authorized to access calendar events. Please request access first.").ThrowAsJavaScriptException();
        return env.Null();
    }

    Napi::Object eventData = info[0].As<Napi::Object>();
    if (!eventData.Has("title") || !eventData.Get("title").IsString() ||
        !eventData.Has("startDate") || !eventData.Get("startDate").IsString() ||
        !eventData.Has("endDate") || !eventData.Get("endDate").IsString()) {
        Napi::TypeError::New(env, "Event data must include title, startDate, and endDate as strings.").ThrowAsJavaScriptException();
        return env.Null();
    }

    NSString* title = [NSString stringWithUTF8String:eventData.Get("title").As<Napi::String>().Utf8Value().c_str()];
    NSDate* startDate = ConvertISOStringToNSDate(env, eventData.Get("startDate").As<Napi::String>());
    NSDate* endDate = ConvertISOStringToNSDate(env, eventData.Get("endDate").As<Napi::String>());

    if (!startDate || !endDate) {
        Napi::TypeError::New(env, "Invalid date format for startDate or endDate. Please use ISO 8601 format.").ThrowAsJavaScriptException();
        return env.Null();
    }
    
    EKEventStore* eventStore = [[EKEventStore alloc] init];
    EKEvent* newEKEvent = [EKEvent eventWithEventStore:eventStore];
    newEKEvent.title = title;
    newEKEvent.startDate = startDate;
    newEKEvent.endDate = endDate;
    newEKEvent.calendar = [eventStore defaultCalendarForNewEvents];

    if (!newEKEvent.calendar) {
        [eventStore release];
        Napi::Error::New(env, "No default calendar found to save the event.").ThrowAsJavaScriptException();
        return env.Null();
    }

    NSError* error = nil;
    BOOL success = [eventStore saveEvent:newEKEvent span:EKSpanThisEvent commit:YES error:&error];
    [eventStore release];

    if (!success || error) {
        std::string errorMsg = "Failed to save event.";
        if (error) {
            errorMsg += " Error: " + std::string([error.localizedDescription UTF8String]);
        }
        Napi::Error::New(env, errorMsg).ThrowAsJavaScriptException();
        return Napi::Boolean::New(env, false);
    }

    return Napi::Boolean::New(env, true);
}

Napi::Value DeleteEvent(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsString()) {
        Napi::TypeError::New(env, "Event identifier string is required.").ThrowAsJavaScriptException();
        return env.Null();
    }

    EKAuthorizationStatus authStatus = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if (authStatus != EKAuthorizationStatusAuthorized) {
        Napi::Error::New(env, "Not authorized to access calendar events. Please request access first.").ThrowAsJavaScriptException();
        return env.Null();
    }

    std::string eventIdStr = info[0].As<Napi::String>().Utf8Value();
    NSString* eventIdentifier = [NSString stringWithUTF8String:eventIdStr.c_str()];

    EKEventStore* eventStore = [[EKEventStore alloc] init];
    EKEvent* eventToRemove = [eventStore eventWithIdentifier:eventIdentifier];

    if (!eventToRemove) {
        [eventStore release];
        // Optionally, you could throw an error here or just return false if event not found is not an error condition.
        // Napi::Error::New(env, "Event with specified identifier not found.").ThrowAsJavaScriptException();
        return Napi::Boolean::New(env, false); 
    }

    NSError* error = nil;
    BOOL success = [eventStore removeEvent:eventToRemove span:EKSpanThisEvent commit:YES error:&error];
    [eventStore release];

    if (!success || error) {
        std::string errorMsg = "Failed to delete event.";
        if (error) {
            errorMsg += " Error: " + std::string([error.localizedDescription UTF8String]);
        }
        Napi::Error::New(env, errorMsg).ThrowAsJavaScriptException();
        return Napi::Boolean::New(env, false);
    }

    return Napi::Boolean::New(env, true);
}

Napi::Value UpdateEvent(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();

    if (info.Length() < 1 || !info[0].IsObject()) {
        Napi::TypeError::New(env, "Event data object is required.").ThrowAsJavaScriptException();
        return env.Null();
    }

    EKAuthorizationStatus authStatus = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if (authStatus != EKAuthorizationStatusAuthorized) {
        Napi::Error::New(env, "Not authorized to access calendar events. Please request access first.").ThrowAsJavaScriptException();
        return env.Null();
    }

    Napi::Object eventData = info[0].As<Napi::Object>();
    if (!eventData.Has("identifier") || !eventData.Get("identifier").IsString()) {
        Napi::TypeError::New(env, "Event data must include an identifier string.").ThrowAsJavaScriptException();
        return env.Null();
    }

    std::string eventIdStr = eventData.Get("identifier").As<Napi::String>().Utf8Value();
    NSString* eventIdentifier = [NSString stringWithUTF8String:eventIdStr.c_str()];

    EKEventStore* eventStore = [[EKEventStore alloc] init];
    EKEvent* eventToUpdate = [eventStore eventWithIdentifier:eventIdentifier];

    if (!eventToUpdate) {
        [eventStore release];
        Napi::Error::New(env, "Event with specified identifier not found for update.").ThrowAsJavaScriptException();
        return Napi::Boolean::New(env, false);
    }

    // Update properties if they exist in eventData
    if (eventData.Has("title") && eventData.Get("title").IsString()) {
        eventToUpdate.title = [NSString stringWithUTF8String:eventData.Get("title").As<Napi::String>().Utf8Value().c_str()];
    }
    if (eventData.Has("startDate") && eventData.Get("startDate").IsString()) {
        NSDate* startDate = ConvertISOStringToNSDate(env, eventData.Get("startDate").As<Napi::String>());
        if (startDate) eventToUpdate.startDate = startDate;
        // else, potentially throw error for invalid date format during update?
    }
    if (eventData.Has("endDate") && eventData.Get("endDate").IsString()) {
        NSDate* endDate = ConvertISOStringToNSDate(env, eventData.Get("endDate").As<Napi::String>());
        if (endDate) eventToUpdate.endDate = endDate;
        // else, potentially throw error for invalid date format during update?
    }
    // Add other updatable properties here: isAllDay, location, notes, etc.
    if (eventData.Has("isAllDay") && eventData.Get("isAllDay").IsBoolean()) {
        eventToUpdate.allDay = eventData.Get("isAllDay").As<Napi::Boolean>().Value();
    }

    NSError* error = nil;
    BOOL success = [eventStore saveEvent:eventToUpdate span:EKSpanThisEvent commit:YES error:&error];
    [eventStore release];

    if (!success || error) {
        std::string errorMsg = "Failed to update event.";
        if (error) {
            errorMsg += " Error: " + std::string([error.localizedDescription UTF8String]);
        }
        Napi::Error::New(env, errorMsg).ThrowAsJavaScriptException();
        return Napi::Boolean::New(env, false);
    }

    return Napi::Boolean::New(env, true);
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
    exports.Set(Napi::String::New(env, "requestAccess"), Napi::Function::New(env, RequestAccess));
    exports.Set(Napi::String::New(env, "getAuthStatus"), Napi::Function::New(env, GetAuthStatus));
    exports.Set(Napi::String::New(env, "getAllEvents"), Napi::Function::New(env, GetAllEvents));
    exports.Set(Napi::String::New(env, "getEventsByName"), Napi::Function::New(env, GetEventsByName));
    exports.Set(Napi::String::New(env, "addNewEvent"), Napi::Function::New(env, AddNewEvent));
    exports.Set(Napi::String::New(env, "deleteEvent"), Napi::Function::New(env, DeleteEvent));
    exports.Set(Napi::String::New(env, "updateEvent"), Napi::Function::New(env, UpdateEvent));
    return exports;
}

NODE_API_MODULE(calendar, Init) 