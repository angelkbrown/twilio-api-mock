require 'fakeredis'
require 'fakeredis/rspec'
require 'spec_helper'

DAY_IN_SECONDS = 24*60*60

describe TwilioRubyMessagesFaker do
  let(:fake_redis) { Redis.new }
  let(:faker) { TwilioRubyMessagesFaker.new(fake_redis) }

  describe '#list' do
    let(:to_param) { message_to }
    let(:date_sent_param) { Time.now.to_date }
    let(:message_to) { '+15559990000' }
    let(:stripped_to) { message_to.gsub('+1', '') }
    let(:message_time_sent) { Time.now.utc }
    let(:message_body) { 'Message' }
    let(:unix_timestamp) { message_time_sent.to_i }
    let(:message) do
      { 'to' => message_to, 'date_sent' => "#{message_time_sent}", 'body' => message_body }
    end
    let(:message_object) { OpenStruct.new(message) }
    let(:expected_list) { [message_object] }

    before do
      message_id = '123'
      fake_redis.zadd(TwilioRubyMessagesFaker::MESSAGE_INDEX_SET, 0,
                      "#{stripped_to}:#{unix_timestamp}:#{message_id}")

      fake_redis.hmset("message:#{message_id}",
                       'to', message_to,
                       'date_sent', message_time_sent,
                       'body', message_body 
                      )
    end

    subject(:list) do
      faker.list(to: to_param, date_sent: date_sent_param)
    end

    context 'message exists for requested date and "to"' do
      let(:to_param) { message_to }
      let(:date_sent_param) { message_time_sent.to_date }

      it 'returns an array containing the message as a ruby hash' do
        expect(list).to eq(expected_list)
      end
    end

    context 'message with requested "to" on preceeding date' do
      let(:message_time_sent) { (Time.now - DAY_IN_SECONDS).utc }
      it 'does not return the message' do
        expect(list).to eq([])
      end
    end

    context 'message with requested "to" on date after' do
      let(:message_time_sent) { (Time.now + DAY_IN_SECONDS).utc }
      it 'does not return the message' do
        expect(list).to eq([])
      end
    end

    context 'no message for requested "to"' do
      let(:to_param) { '+19999999999' }

      it 'does not find any messages' do
        expect(list).to eq([])
      end
    end

    context 'multiple messages on the same day' do 
      let(:message2_time_sent) { (Time.now - 3600).utc }
      let(:message2_body) { 'Message 2' }
      let(:message2) do
        { 'to' => message_to, 'date_sent' => "#{message2_time_sent}", 'body' => message2_body }
      end
      let(:message2_object) { OpenStruct.new(message2) }
      let(:expected_list) { [message_object, message2_object] }

      before do
        message2_id = '345'
        fake_redis.zadd(TwilioRubyMessagesFaker::MESSAGE_INDEX_SET, 0,
                        "#{stripped_to}:#{message2_time_sent.to_i}:#{message2_id}")

        fake_redis.hmset("message:#{message2_id}",
                        'to', message_to,
                        'date_sent', message2_time_sent,
                        'body', message2_body
                        )
      end

      it 'returns all messages with requested "to"' do
        expect(list.include?(message_object)).to eq(true)
        expect(list.include?(message2_object)).to eq(true)
      end

      context 'additional messages on same day with different "to"' do
        let(:different_message_to) { '+18889997777' }
        let(:different_message_stripped_to) { different_message_to.gsub('+1','') }

        before do
          different_message_id = 999
          fake_redis.zadd(TwilioRubyMessagesFaker::MESSAGE_INDEX_SET, 0,
                          "#{different_message_stripped_to}:#{message2_time_sent.to_i}:#{different_message_id}")
          fake_redis.hmset("#{different_message_id}",
                          'to', different_message_to,
                          'date_sent', message2_time_sent,
                          'body', 'Different message'
                          )
        end

        it 'does not return message with different "to"' do
          expect(list.select{ |msg| msg.to == message_to }.present?).to eq(true)
          expect(list.select{ |msg| msg.to == different_message_to }.present?).to eq(false)
        end
      end
    end
  end

  describe '#create' do
    let(:from) { '+19997776666' }
    let(:to) { '+15557778888' }
    let(:body) { 'Message' }
    let(:date_sent) { Time.now.utc }
    let(:expected_date_sent) { date_sent.utc }
    let(:expected_redis_record) do
      {
        'from' => from,
        'to' => to,
        'body' => body,
        'date_sent' => "#{date_sent}"
      }
    end

    subject(:create) do
      faker.create(from: from, to: to, body: body, date_sent: date_sent)
    end

    it 'creates a hash in redis with id message:1' do
      create
      expect(fake_redis.hgetall('message:1')).to eq(expected_redis_record)
    end

    it 'creates the composite index sorted set element' do
      create
      stripped_to = to.gsub('+1','')
      index = fake_redis.zrangebylex(TwilioRubyMessagesFaker::MESSAGE_INDEX_SET,
                                    "(#{stripped_to}:#{date_sent.to_i}",
                                    "(#{stripped_to}:#{(date_sent + 1).to_i}")
      expect(index.present?).to eq(true)
    end

    context 'multiple messages are created' do
      before do
        faker.create(from: from, to: to, body: body, date_sent: date_sent)
      end

      it 'increments the id' do
        create
        expect(fake_redis.hgetall('message:2').present?).to eq(true)
      end
    end
  end
end
