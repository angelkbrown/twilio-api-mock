require 'twilio_api_mock/version'
require 'ostruct'

module TwilioApiMock
  class Messages
    attr_reader :redis

    MESSAGE_INDEX_SET = 'message_index'

    def initialize(redis_instance)
      @redis = redis_instance
    end

    # In order to search by phone number within a time range, we use
    # a sorted set to create a composite index using phone (to) and
    # "date_sent" (time sent) which stores the id for the hashed message.
    # https://redis.io/topics/indexes#composite-indexes
    def create(from:, to:, body:, date_sent: Time.now)
      message_id = "message:#{next_message_id}"

      # Add composite index
      redis.zadd(MESSAGE_INDEX_SET, 0,
                 "#{to}:#{date_sent.to_i}:#{message_id}")

      # Add message hash
      redis.hmset(message_id,
                  'from', from,
                  'to', to,
                  'body', body,
                  'date_sent', date_sent
                 )
    end

    # This returns all messages for a given 'to' which
    # occur at any time on a given date.
    def list(to:, date_sent:)
      # Get beginning and end of date_sent
      range_start, range_end = unix_time_range(date_sent)

      # Lexicographical search by phone (to) and time range
      # to get the message index
      message_indexes = redis.zrangebylex(MESSAGE_INDEX_SET,
                                          "(#{to}:#{range_start}",
                                          "[#{to}:#{range_end}")

      return [] if message_indexes.empty?

      message_ids = message_indexes.map{ |index| index.split(':').last }

      # Return all messages as OpenStructs
      message_ids.map do |id|
        if message_hash = redis.hgetall("message:#{id}")
          OpenStruct.new(message_hash)
        end
      end
    end

    private

    # Returns [beginning of day, end of day]
    def unix_time_range(date)
      range_start = date.to_time.to_i
      range_end = (date + 1).to_time.to_i
      [range_start, range_end]
    end

    # Increment message id
    def next_message_id
      if max_message_id = redis.get('max_message_id')
        next_id = max_message_id.to_i + 1
      else
        next_id = 1
      end

      redis.set('max_message_id', next_id)
      next_id
    end
  end
end
