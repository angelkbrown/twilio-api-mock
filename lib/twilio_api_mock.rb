require 'twilio_api_mock/version'
require 'ostruct'

module TwilioApiMock
  class Messages
    attr_reader :redis

    MESSAGE_INDEX_SET = 'message_index'
    DAY_IN_SECONDS = 24*60*60

    def initialize(redis_instance)
      @redis = redis_instance
    end

    # In order to search by phone number within a time range, we use
    # a sorted set to create a composite index using phone (to) and
    # "date_sent" (time sent) which stores the id for the hashed message.
    # https://redis.io/topics/indexes#composite-indexes
    def create(from:, to:, body:, date_sent: Time.now)
      raise 'from must be a String' unless from.is_a?(String)
      raise 'to must be a String' unless to.is_a?(String)
      raise 'date_sent must be a Time' unless date_sent.is_a?(Time)

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
      raise 'to must be a String' unless to.is_a?(String)
      #TODO: Check that date_sent matches expected format.
      # (If date_sent is a string without the expected format, the start date
      # will be something like 0000-01-01.
      raise 'date_sent must be a String with format yyyy-mm-dd' unless date_sent.is_a?(String)

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
      range_start = Time.parse(date)
      range_end = range_start + DAY_IN_SECONDS
      [range_start.to_i, range_end.to_i]
    end

    # Increment message id
    # TODO: Slight possibility two messages
    # could end up with the same id.
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
