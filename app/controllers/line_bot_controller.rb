class LineBotController < ApplicationController
  protect_from_forgery except: [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']#署名を参照：HTTP_X_LINE_SIGNATUREに署名が格納
    unless client.validate_signature(body, signature)
      return head :bad_request#headメソッドはステータスコードを返したいときに使用、:bad_requestで400を返す
    end
      events = client.parse_events_from(body)
      events.each do |event|
        case event
        when Line::Bot::Event::Message
          case event.type
          when Line::Bot::Event::MessageType::Text
            message = search_and_create_message(event.message['text'])#search_and_create_messageメソッドにユーザーから送信されたメッセージであるevent.message['text']を引数に指定します。
            client.reply_message(event['replyToken'], message)#返信機能実装
          end
        end
      end
      head :ok#返信機能実装 OKはHTTPステータスで200を表す
  end

  private

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def search_and_create_message(keyword)
    http_client = HTTPClient.new
      url = 'https://app.rakuten.co.jp/services/api/Travel/KeywordHotelSearch/20170426'
      query = {
        'keyword' => keyword,
        'applicationId' => ENV['RAKUTEN_APPID'],
        'hits' => 5,
        'responseType' => 'small',
        'datumType' => 1,
        'formatVersion' => 2
      }
      response = http_client.get(url, query)
      response = JSON.parse(response.body)

    if response.key?('error')
        text = "この検索条件に該当する宿泊施設が見つかりませんでした。\n条件を変えて再検索してください。"
    else
        text = ''
      response['hotels'].each do |hotel|
        text <<
          hotel[0]['hotelBasicInfo']['hotelName'] + "\n" +
          hotel[0]['hotelBasicInfo']['hotelInformationUrl'] + "\n" +
          "\n"
      end
    end

      message = {
        type: 'text',
        text: text
      }
  end
end
