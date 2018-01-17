class TrainCheck
  require 'csv'
  require 'json'
  require 'uri'
  require 'net/http'
  require 'slack/incoming/webhooks'
  @user_settings

  def self.execute
    new.execute
  end

  #第一引数(ARGV[0]) メッセージを投稿したいslackのコンフィグファイルのパス
  #第二引数(ARGV[1]) 遅延情報がほしい路線の情報を記したcsvファイルのパス
  def execute
    #日本全国の遅れている電車の一覧を取得する
    delay_trains = Hash.new { |h, k| h[k] = [] }
    delay_trains = get_delay_trains('https://rti-giken.jp/fhc/api/train_tetsudo/delay.json')

    puts delay_trains
    post_slack("遅延している電車は存在しません") if delay_trains.empty?
    post_message = build_message(ARGV[1], delay_trains)
    post_slack(post_message)
  end

  def initialize
    @user_settings = load_settings(ARGV[0])
    return puts "設定ファイルが存在しません" unless File.exist?(ARGV[0])
  end

  def load_settings(setting_file_path)
    File.open(setting_file_path) do |j|
      JSON.load(j)
    end
  end

  #遅延している電車一覧を取得して，後で使用しやすいhash形式にした上で返却する
  def get_delay_trains(json_url)
    url = URI.parse(json_url)
    json = Net::HTTP.get(url)
    result = JSON.parse(json)

    tmp_result_data = []
    result.each do |train_data|
      tmp_result_data << [train_data["company"],train_data["name"]]
    end
    delay_trains = Hash.new { |h, k| h[k] = [] }
    tmp_result_data.each do |k, v|
      delay_trains[k] << v
    end

    delay_trains
  end
  
  #slackに投稿する文章を構築する
  def build_message(csv_path, delay_trains)
    return "取得したい路線のcsvが存在しません" unless File.exist?(csv_path) 
    csv = CSV.read(csv_path)
    message = ""
    csv.each do |necessary_train|
      if delay_trains.has_key?(necessary_train[0])
        if delay_trains[necessary_train[0]].include?(necessary_train[1])
          #necessary_trainは下記の構造
          #鉄道会社名，路線名，URL（遅れているときに見たいURL）
          message << <<-MSG
            #{necessary_train[0]}：#{necessary_train[1]} が遅れています。\r\n
            URL：#{necessary_train[2]}\r\n\r\n
          MSG
        end
      end
    end
    return "あなたに関係している，遅延電車は存在しません。" if message.empty?
    message
  end
  
  #slackに投稿する
  def post_slack(message)
    return puts "設定ファイルが間違っています。" if @user_settings["url"].empty? || @user_settings["cannel"].empty?

    puts "url：#{@user_settings["url"]}"
    puts "cannel：#{@user_settings["cannel"]}"
    puts "message：#{message}"

    slack = Slack::Incoming::Webhooks.new @user_settings["url"]
    slack.channel = @user_settings["cannel"]
    slack.post message
    puts "slackに投稿しました"
  end
end
TrainCheck.execute
