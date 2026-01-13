require 'net/http'
require 'json'
require 'uri'
require 'dotenv/load'

class MessageParser
  API_KEY = ENV['OPENAI_API_KEY']
  API_URL = 'https://api.openai.com/v1/chat/completions'
  TELEGRAM_BOT_TOKEN = ENV['TELEGRAM_BOT_TOKEN']
  TELEGRAM_CHAT_ID = ENV['TELEGRAM_CHAT_ID']
  OUTPUT_FILE = 'result.txt'

  def initialize
    validate_api_key
    validate_telegram_config
  end

  def parse_and_save(message)
    return if message.nil? || message.strip.empty?

    puts "Processing message..."
    parsed_data = extract_fields(message)
    
    if parsed_data
      save_to_file(parsed_data, message)
      display_result(parsed_data)
      send_to_telegram(parsed_data) if @telegram_enabled
    else
      puts "Failed to parse message"
    end
  end

  private

  def validate_api_key
    raise 'OPENAI_API_KEY environment variable not set' if API_KEY.nil? || API_KEY.empty?
  end

  def validate_telegram_config
    if TELEGRAM_BOT_TOKEN.nil? || TELEGRAM_BOT_TOKEN.empty?
      puts "⚠️  Warning: TELEGRAM_BOT_TOKEN not set. Telegram notifications disabled."
      @telegram_enabled = false
    elsif TELEGRAM_CHAT_ID.nil? || TELEGRAM_CHAT_ID.empty?
      puts "⚠️  Warning: TELEGRAM_CHAT_ID not set. Telegram notifications disabled."
      @telegram_enabled = false
    else
      @telegram_enabled = true
    end
  end

  def extract_fields(message)
    prompt = build_prompt(message)
    response = call_openai_api(prompt)
    parse_ai_response(response)
  rescue StandardError => e
    log_error(e)
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
    uri = URI(API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{API_KEY}"
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

    puts "\n✓ Data saved to #{OUTPUT_FILE}"
  rescue StandardError => e
    log_error(e)
  end

  def format_entry(data, original_message, timestamp)
    <<~ENTRY
      ===== Processed at: #{timestamp} =====
      JADWAL SURVEY:
      - Phone Number : #{data[:phone_number]}
      - Date         : #{data[:date]}
      - Time         : #{data[:time]}
      - Name         : #{data[:name]}
      #{'=' * 50}

    ENTRY
  end

  def display_result(data)
    puts "\n📋 Extracted Information:"
    puts "  📞 Phone: #{data[:phone_number]}"
    puts "  📅 Date: #{data[:date]}"
    puts "  🕐 Time: #{data[:time]}"
    puts "  👤 Name: #{data[:name]}"
  end

  def log_error(error)
    puts "❌ Error: #{error.message}"
  end

  def send_to_telegram(data)
    message = format_telegram_message(data)
    
    uri = URI("https://api.telegram.org/bot#{TELEGRAM_BOT_TOKEN}/sendMessage")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json'
    })

    request.body = {
      chat_id: TELEGRAM_CHAT_ID,
      text: message,
      parse_mode: 'HTML'
    }.to_json

    response = http.request(request)
    
    if response.code == '200'
      puts "✓ Sent to Telegram"
    else
      puts "⚠️  Failed to send to Telegram: #{response.code} #{response.body}"
    end
  rescue StandardError => e
    puts "⚠️  Telegram error: #{e.message}"
  end

  def format_telegram_message(data)
    timestamp = Time.now.strftime('%d %B %Y, %H:%M:%S')
    
    <<~MESSAGE.strip
      🔔 <b>JADWAL SURVEY BARU</b>

      📅 <b>Tanggal:</b> #{data[:date]}
      🕐 <b>Waktu:</b> #{data[:time]}
      👤 <b>Nama:</b> #{data[:name]}
      📞 <b>No. HP:</b> #{data[:phone_number]}
    MESSAGE
  end
end

def main
  puts "📱 Message Parser v1.0"
  puts "=" * 50
  
  parser = MessageParser.new

  if ARGV.empty?
    puts "\n❌ No message provided!"
    puts "\nUsage: ruby main.rb \"your message here\""
    puts "\nExamples:"
    puts '  ruby main.rb "Halo, saya Budi 081234567890. Booking untuk hari Senin, 15 Januari jam 14:00"'
    puts '  ruby main.rb "Pak, ini Andi. Nomor saya 0812-3456-7890, mau booking Jumat 17 Jan pukul 10 pagi"'
    puts '  ruby main.rb "Saya Romy +6281234567890, booking tanggal 20 Januari hari Rabu jam 3 sore"'
    exit 1
  end

  message = ARGV.join(' ')
  puts "\n📩 Message: #{message}\n"
  
  parser.parse_and_save(message)
  puts "\n✅ Done!"
  
rescue StandardError => e
  puts "\n❌ Fatal error: #{e.message}"
  exit 1
end

main if __FILE__ == $PROGRAM_NAME
