class TwilioRubyMessagesFaker
  attr_reader :redis

  MESSAGE_INDEX_SET = 'message_index'

  def initialize(redis_instance)
    @redis = redis_instance
  end

  def list(to:, date_sent:)
    range_start, range_end = unix_time_range(date_sent)

    message_indexes = redis.zrangebylex(MESSAGE_INDEX_SET,
                                      "(#{stripped_to(to)}:#{range_start}",
                                      "[#{stripped_to(to)}:#{range_end}")

    return [] if message_indexes.blank?

    message_ids = message_indexes.map{ |index| index.split(':').last }

    message_ids.map do |id|
      if message_hash = redis.hgetall("message:#{id}")
        OpenStruct.new(message_hash)
      end
    end
  end

  def create(from:, to:, body:, date_sent: Time.now)
    message_id = "message:#{next_message_id}"

    # Add composite index
    redis.zadd(MESSAGE_INDEX_SET, 0,
               "#{stripped_to(to)}:#{date_sent.to_i}:#{message_id}")

    # Add message hash
    redis.hmset(message_id,
                'from', from,
                'to', to,
                'body', body,
                'date_sent', date_sent
               )
  end

  private

  def unix_time_range(date)
    range_start = date.to_time.to_i
    range_end = (date + 1).to_time.to_i
    [range_start, range_end]
  end

  def next_message_id
    if previous_id = redis.get('next_message_id')
      next_id = previous_id.to_i + 1
    else
      next_id = 1
    end
    redis.set('next_message_id', next_id)
    next_id
  end

  def stripped_to(to)
    to.gsub('+1','')
  end
end
