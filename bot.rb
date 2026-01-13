require 'net/http'
require 'json'
require 'uri'
require 'dotenv/load'

class TelegramBot
  TELEGRAM_BOT_TOKEN = ENV['TELEGRAM_BOT_TOKEN']
  OPENAI_API_KEY = ENV['OPENAI_API_KEY']
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  OUTPUT_FILE = 'result.txt'

  def initialize
    validate_config
    @last_update_id = 0
    puts "🤖 Telegram Bot Started"
    puts "=" * 50
    puts "Waiting for messages..."
    puts "Send me a booking message to parse!\n\n"
  end

  def start
    loop do
      process_updates
      sleep 2
    end
  rescue Interrupt
    puts "\n\n👋 Bot stopped"
  end

  private

  def validate_config
    raise 'TELEGRAM_BOT_TOKEN not set' if TELEGRAM_BOT_TOKEN.nil? || TELEGRAM_BOT_TOKEN.empty?
    raise 'OPENAI_API_KEY not set' if OPENAI_API_KEY.nil? || OPENAI_API_KEY.empty?
  end

  def process_updates
    updates = get_updates
    return unless updates && updates['ok']

    updates['result'].each do |update|
      next unless update['message']
      
      message = update['message']
      chat_id = message['chat']['id']
      text = message['text']
      
      next if text.nil? || text.strip.empty?
      next if text.start_with?('/')
      
      @last_update_id = update['update_id'] + 1
      
      puts "\n📩 New message from #{message['from']['first_name']} (#{chat_id})"
      puts "   Text: #{text}"
      
      process_message(chat_id, text)
    end
  rescue StandardError => e
    puts "❌ Error processing updates: #{e.message}"
  end

  def get_updates
    uri = URI("https://api.telegram.org/bot#{TELEGRAM_BOT_TOKEN}/getUpdates")
    uri.query = URI.encode_www_form(
      offset: @last_update_id,
      timeout: 30
    )

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 35

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    
    JSON.parse(response.body)
  rescue StandardError => e
    puts "❌ Error getting updates: #{e.message}"
    nil
  end

  def process_message(chat_id, text)
    send_telegram_message(chat_id, "⏳ Processing your message...")
    
    parsed_data = extract_fields(text)
    
    if parsed_data
      save_to_file(parsed_data, text)
      send_success_message(chat_id, parsed_data)
      puts "   ✓ Parsed and saved"
    else
      send_telegram_message(chat_id, "❌ Sorry, I couldn't parse the booking information from your message.\n\nPlease include: name, phone number, date, and time.")
      puts "   ✗ Failed to parse"
    end
  rescue StandardError => e
    send_telegram_message(chat_id, "❌ Error: #{e.message}")
    puts "   ❌ Error: #{e.message}"
  end

  def extract_fields(message)
    prompt = build_prompt(message)
    response = call_openai_api(prompt)
    parse_ai_response(response)
  rescue StandardError => e
    puts "   ❌ AI Error: #{e.message}"
    nil
  end

  def build_prompt(message)
    <<~PROMPT
      Extract the following information from this Indonesian message and return ONLY a valid JSON object:
      - phone_number: Indonesian phone number (format: +62xxx or 08xxx)
      - date: Date with day name in Indonesian (e.g., "Senin, 15 Januari 2026")
      - time: Time in 24-hour format (e.g., "14:00")
      - name: Person's name

      Message: "#{sanitize_input(message)}"

      Return format:
      {"phone_number":"","date":"","time":"","name":""}

      Rules:
      - Extract phone number in any format (with/without +62, with/without spaces)
      - Normalize date to include day name if not present
      - Convert time to 24-hour format
      - Extract full name
      - If any field is not found, use empty string
      
      Return only the JSON, no explanation.
    PROMPT
  end

  def sanitize_input(text)
    text.gsub(/["\\\n\r\t]/, ' ').strip
  end

  def call_openai_api(prompt)
    uri = URI(OPENAI_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{OPENAI_API_KEY}"
    })

    request.body = {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are a data extraction assistant. Return only valid JSON.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.3,
      max_tokens: 200
    }.to_json

    response = http.request(request)
    raise "API error: #{response.code}" unless response.code == '200'

    JSON.parse(response.body)
  end

  def parse_ai_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    return nil unless content

    json_match = content.match(/\{.*\}/m)
    return nil unless json_match

    data = JSON.parse(json_match[0])
    validate_extracted_data(data)
  end

  def validate_extracted_data(data)
    required_keys = %w[phone_number date time name]
    return nil unless required_keys.all? { |key| data.key?(key) }

    {
      phone_number: sanitize_phone(data['phone_number']),
      date: data['date'].to_s.strip,
      time: data['time'].to_s.strip,
      name: data['name'].to_s.strip
    }
  end

  def sanitize_phone(phone)
    return '' if phone.nil? || phone.empty?
    phone.gsub(/[^\d+]/, '').slice(0, 15)
  end

  def save_to_file(data, original_message)
    timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
    entry = format_entry(data, original_message, timestamp)

    File.open(OUTPUT_FILE, 'a') do |file|
      file.puts entry
    end
  rescue StandardError => e
    puts "   ❌ Save error: #{e.message}"
  end

  def format_entry(data, original_message, timestamp)
    <<~ENTRY
      ===== Processed at: #{timestamp} =====
      Original Message: #{original_message}
      
      JADWAL SURVEY:
      - Phone Number : #{data[:phone_number]}
      - Date         : #{data[:date]}
      - Time         : #{data[:time]}
      - Name         : #{data[:name]}
      #{'=' * 50}

    ENTRY
  end

  def send_success_message(chat_id, data)
    message = format_success_message(data)
    send_telegram_message(chat_id, message)
  end

  def format_success_message(data)
    <<~MESSAGE.strip
      ✅ <b>Booking berhasil diparsing!</b>

      📅 <b>Tanggal:</b> #{data[:date]}
      🕐 <b>Waktu:</b> #{data[:time]}
      👤 <b>Nama:</b> #{data[:name]}
      📞 <b>No. HP:</b> #{data[:phone_number]}
    MESSAGE
  end

  def send_telegram_message(chat_id, text)
    uri = URI("https://api.telegram.org/bot#{TELEGRAM_BOT_TOKEN}/sendMessage")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json'
    })

    request.body = {
      chat_id: chat_id,
      text: text,
      parse_mode: 'HTML'
    }.to_json

    response = http.request(request)
    
    unless response.code == '200'
      puts "   ⚠️  Failed to send message: #{response.code}"
    end
  rescue StandardError => e
    puts "   ⚠️  Telegram error: #{e.message}"
  end
end

def main
  bot = TelegramBot.new
  bot.start
rescue StandardError => e
  puts "\n❌ Fatal error: #{e.message}"
  exit 1
end

main if __FILE__ == $PROGRAM_NAME
