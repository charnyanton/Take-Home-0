# stackOverflowTestTask

Test task iOS application that loads StackOverflow users, displays them in a UIKit list, supports local follow/unfollow state with persistence between launches, and presents a user detail screen.

## Requirements

- Xcode 17 or newer
- iOS Simulator with iOS 17.0+ runtime
- Swift 5

## Setup Instructions

1. Clone the repository.
2. Open `stackOverflowTestTask.xcodeproj` in Xcode.
3. Select the `stackOverflowTestTask` scheme.
4. Run the app on an iPhone simulator.

## How the App Works

### Launch flow

- The app uses a programmatic UIKit bootstrap.
- `SceneDelegate` creates the window and root navigation controller.
- `AppCoordinator` creates all feature dependencies and sets the user list screen as the root view controller.

### User list flow

- On launch, `UserListViewController` asks `UserListViewModel` to load data.
- `UserListViewModel` switches the screen to a loading state.
- `UsersRepository` sends a request to the Stack Exchange API and maps the response into `StackUser`.
- The view model merges remote users with locally persisted follow state.
- The screen renders the top 20 users with:
  - avatar
  - display name
  - reputation
  - follow/unfollow button
  - visual `Following` indicator for followed users
- When the last visible user cell appears and the API reports more pages, the list requests the next page and appends those users.
- The sort menu in the navigation bar lets the user reload the list by:
  - reputation
  - creation date
  - display name
  - last modified date
  - ascending or descending order

### User detail flow

- Tapping a user row pushes a detail screen through `AppCoordinator`.
- The detail screen renders:
  - profile picture
  - display name
  - reputation
  - current follow status
  - follow/unfollow button
  - location, with a fallback when the API does not provide it
  - website URL when available
- Follow/unfollow on the detail screen updates the same `FollowStore` used by the list.
- When returning to the list, the list view model refreshes visible follow state from the store without refetching remote users.

### Follow flow

- Follow/unfollow is local only.
- Tapping the button updates the current item state in the view model.
- The new state is saved in `UserDefaults` through `UserDefaultsFollowStore`.
- On the next app launch, followed users are restored by `userID`.
- Detail and list screens share the same store, so a follow change on either screen uses the same persisted source of truth.

### Error handling

- If the request fails or the server is unavailable, the screen shows an empty state with an error message.
- If the API returns an empty list, the screen shows an empty state for no users found.

## Technical Decisions

### Architecture

The app uses `MVVM + Coordinator`.

- `Coordinator` is responsible for composition and navigation setup.
- `ViewController` is responsible only for UIKit rendering and user interaction forwarding.
- `ViewModel` owns screen state and presentation logic.
- `Repository` owns networking and DTO-to-domain mapping.
- `FollowStore` owns local follow persistence.

This keeps responsibilities small and makes the core logic easier to test without depending on UIKit.

### UIKit and programmatic UI

- UIKit was used to match the task requirements.
- The main UI is built programmatically instead of using `Main.storyboard`.
- This makes coordinator-based composition explicit and keeps screen setup in code.

### Networking

- The app uses a small `HTTPClientProtocol` abstraction over `URLSession`.
- `UsersRepository` builds the request, validates the status code, decodes the payload, and maps it to domain models.
- Sort option, order, page, and page size are passed into the repository so API query construction remains outside the UI layer.
- Although the task description shows an `http` URL, the app uses `https` to avoid ATS issues and to use the current secure endpoint.

### Local persistence

- Follow state is stored as a set of `userID` values in `UserDefaults`.
- Only the minimal local state is persisted.
- The remote user list itself is not cached.

This keeps the implementation simple and aligned with the task scope.

### Images

- Remote avatars are loaded with a lightweight image loader built on top of `URLSession`.
- Images are cached in memory with `NSCache`.
- Cell image requests are cancelled on reuse to avoid incorrect image assignment.

### Testing

The project includes unit tests for the core logic:

- `UsersRepositoryTests`
  - request building
  - payload mapping
  - transport errors
  - invalid responses
  - decoding failures
- `UserDefaultsFollowStoreTests`
  - persistence
  - unfollow flow
  - duplicate handling
  - recovery from unexpected stored values
- `UserListViewModelTests`
  - loading state
  - content state
  - empty and error states
  - follow/unfollow toggling
  - persistence restore after reload
  - visible follow-state refresh after returning from detail
  - sort option and sort order reload behavior
  - next-page loading and pagination guard behavior
  - detail navigation callback
  - several edge cases
- `UserDetailViewModelTests`
  - detail presentation data
  - follow/unfollow persistence
  - optional website and missing location behavior

## Project Structure

```text
stackOverflowTestTask/
├── Application
├── Core
├── Data
├── Infrastructure
├── Presentation
└── stackOverflowTestTaskTests
```

## Notes

- No third-party libraries are used.
- The app intentionally does not implement pagination, search, or remote caching because they are outside the scope of the task.
- The current implementation is focused on clarity, testability, and a small amount of infrastructure for a compact two-screen app.
