# Ruby-based Animal Photo Bot for Bluesky
This Bluesky bot is capable of posting a random animal photo or responding to replies/mentions with a selection of five species.
Random animal API selection is based on https://github.com/treboryx/animalsAPI

Live instance is available at https://bsky.app/profile/ruby-bot.bsky.social

## Setup
1. Ensure that Ruby is installed in your environment.
2. Run `bundle install` to install the dependencies from `Gemfile`.
3. Create a file named `bsky.env` with the following contents:
   ```
   BSKY_IDENTIFIER="your_bsky_identifier_here"
   BSKY_APP_PASSOWRD="your_bsky_app_password_here"
   ```

## Usage
`bot.rb` takes one of the following arguments:
- `random` - Posts a random animal photo to the timeline
- `reply` - Replies to any unread reply or mention notifications with a random animal photo. If the reply matches the string of an animal species, it will post an image of that species. If not, the selection is random.
