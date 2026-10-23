/*
 async / await

 1. Why async/await
    1.1 Callback hell
    1.2 The same with async/await

 2. Wrapping closures
    2.1 withCheckedContinuation
    2.2 Wrappers and deprecation
    2.3 Continuation pitfalls

 3. Multiple tasks
    3.1 Sequential caveat
    3.2 async let
    3.3 TaskGroup

 4. Actors
    4.1 Actors vs classes
    4.2 Actor reentrancy
    4.3 MainActor


 Migration plan

 - New features / screens: async/await only, view models are @MainActor
 - Existing services/managers: don't rewrite, add an async wrapper next to the closure method
 - Later, per service: make async the real implementation, closure method becomes a wrapper
   marked @available(*, deprecated, renamed: "...") so we get warnings + fix-it on old call sites
 - When there are no warnings left for a service, delete the closure method


 Rules

 - continuation must be resumed exactly once
 - callback called many times (progress, location) -> AsyncStream
 - independent calls -> async let / TaskGroup, dependent calls -> await one by one
 - shared mutable state -> actor, UI -> @MainActor
 - inside an actor, state can change after any await


 Sources

 https://www.avanderlee.com/swift/async-await/
 https://www.avanderlee.com/swift/async-let-asynchronous-functions-in-parallel/
 https://www.avanderlee.com/concurrency/task-groups-in-swift/
 https://www.avanderlee.com/swift/actors/
 https://www.avanderlee.com/swift/mainactor-dispatch-main-thread/
 https://developer.apple.com/documentation/swift/checkedcontinuation
 WWDC21: Meet async/await in Swift, Protect mutable state with Swift actors
 */
