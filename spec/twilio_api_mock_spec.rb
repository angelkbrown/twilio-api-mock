require "spec_helper"

RSpec.describe TwilioApiMock::Messages do
  let(:fake_redis) { Redis.new }
  let(:messages_mock) { TwilioApiMock::Messages.new(fake_redis) }

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
      messages_mock.create(from: from, to: to, body: body, date_sent: date_sent)
    end

    context 'valid params' do
      it 'creates a hash in redis with id message:1' do
        create
        expect(fake_redis.hgetall('message:1')).to eq(expected_redis_record)
      end

      it 'creates the composite index sorted set element' do
        create
        index = fake_redis.zrangebylex(TwilioApiMock::Messages::MESSAGE_INDEX_SET,
                                       "(#{to}:#{date_sent.to_i}",
                                       "(#{to}:#{(date_sent + 1).to_i}")

        expect(index.any?).to eq(true)
      end
    end

    context 'invalid params' do
      context '"to" is invalid' do
        let(:to) { 1 }

        it 'raises an error' do
          expect { create }.to raise_error 'to must be a String'
        end
      end

      context '"from" is invalid' do
        let(:from) { 1 }
        it 'raises an error' do
          expect { create }.to raise_error 'from must be a String'
        end
      end

      context '"date_sent" is invalid' do
        let(:date_sent) { 'not a time' }
        it 'raises an error' do
          expect { create }.to raise_error 'date_sent must be a Time'
        end
      end
    end

    context 'multiple messages are created' do
      before do
        messages_mock.create(from: from, to: to, body: body, date_sent: date_sent)
      end

      it 'increments the id' do
        # The above 'before' should create message:1
        expect(fake_redis.hgetall('message:1').any?).to eq(true)
        # We should not already have a 'message:2'
        expect(fake_redis.hgetall('message:2').any?).to eq(false)

        create
        # Now we should have message:2
        expect(fake_redis.hgetall('message:2').any?).to eq(true)
      end
    end
  end

  describe '#list' do
    let(:to_param) { message_to }
    let(:date_sent_param) { Date.new(2017, 6, 1).to_s }
    let(:message_to) { '+15559990000' }
    let(:message_time_sent) { Time.new(2017, 6, 1, 15, 0, 10, '+00:00') }
    let(:message_body) { 'Message' }
    let(:unix_timestamp) { message_time_sent.to_i }
    let(:message_object) do
      OpenStruct.new(
        {
          'to' => message_to,
          'date_sent' => "#{message_time_sent}",
          'body' => message_body
        }
      )
    end
    let(:expected_list) { [message_object] }

    subject(:list) do
      messages_mock.list(to: to_param, date_sent: date_sent_param)
    end

    context 'invalid params' do
      context '"to" is invalid' do
        let(:to_param) { 1 }

        it 'raises an error' do
          expect { list }.to raise_error 'to must be a String'
        end
      end

      context '"date_sent" is invalid' do
        let(:date_sent_param) { Time.now.to_date }

        it 'raises an error' do
          expect { list }.to raise_error 'date_sent must be a String with format yyyy-mm-dd'
        end
      end
    end

    context 'valid params' do
      context 'messages do not exist' do
        it { is_expected.to be_empty }
      end

      context 'messages exist' do
        before do
          # Add message and its composite index
          message_id = '123'
          fake_redis.zadd(TwilioApiMock::Messages::MESSAGE_INDEX_SET, 0,
                          "#{message_to}:#{unix_timestamp}:#{message_id}")

          fake_redis.hmset("message:#{message_id}",
                           'to', message_to,
                             'date_sent', message_time_sent,
                             'body', message_body
                          )
        end

        context 'message exists for requested date and "to"' do
          let(:to_param) { message_to }
          let(:date_sent_param) { message_time_sent.to_date.to_s }

          it 'returns an array containing the message as a ruby object' do
            expect(list).to eq(expected_list)
          end
        end

        context 'message exists with requested "to" on preceeding date' do
          let(:message_time_sent) do
            (Time.new(2017, 6, 1, 15, 0, 10, "+00:00") - TwilioApiMock::Messages::DAY_IN_SECONDS).utc
          end

          it { is_expected.to be_empty }
        end

        context 'message exists with requested "to" on date after' do
          let(:message_time_sent) do
            (Time.new(2017, 6, 1, 15, 0, 10, "+00:00") + TwilioApiMock::Messages::DAY_IN_SECONDS).utc
          end

          it { is_expected.to be_empty }
        end

        context 'no message exists for requested "to"' do
          let(:to_param) { '+19999999999' }

          it { is_expected.to be_empty }
        end

        context 'multiple messages on the same day' do
          let(:message2_time_sent) { Time.new(2017, 6, 1, 16, 0, 10, '+00:00') }
          let(:message2_body) { 'Message 2' }
          let(:message2_object) do
            OpenStruct.new(
              {
                'to' => message_to,
                'date_sent' => "#{message2_time_sent}",
                'body' => message2_body
              }
            )
          end
          let(:expected_list) { [message_object, message2_object] }

          before do
            message2_id = '345'
            fake_redis.zadd(TwilioApiMock::Messages::MESSAGE_INDEX_SET, 0,
                            "#{message_to}:#{message2_time_sent.to_i}:#{message2_id}")

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

            before do
              different_message_id = 999
              fake_redis.zadd(TwilioApiMock::Messages::MESSAGE_INDEX_SET, 0,
                              "#{different_message_to}:#{message2_time_sent.to_i}:#{different_message_id}")

              fake_redis.hmset("#{different_message_id}",
                               'to', different_message_to,
                               'date_sent', message2_time_sent,
                               'body', 'Different message'
                              )
            end

            it 'does not return message with different "to"' do
              expect(list.select{ |msg| msg.to == message_to }.any?).to eq(true)
              expect(list.select{ |msg| msg.to == different_message_to }.any?).to eq(false)
            end

            it 'still returns all messages with requested "to"' do
              expect(list.include?(message_object)).to eq(true)
              expect(list.include?(message2_object)).to eq(true)
            end
          end
        end
      end
    end
  end
end
