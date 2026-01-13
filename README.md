# Message Parser - Book Reminder

Ruby script that intelligently extracts booking information from random Indonesian messages using OpenAI API.

## Features

- 🤖 AI-powered message parsing (OpenAI GPT-4o-mini)
- 📞 Extracts phone numbers (any format)
- 📅 Extracts dates with Indonesian day names
- 🕐 Extracts time (converted to 24-hour format)
- 👤 Extracts person's name
- 💾 Appends results to `result.txt`
- � Sends notifications to Telegram
- �🔒 Secure (no hardcoded secrets)

## Setup

1. Install Ruby (version 2.7 or higher recommended)

2. Install required gem:
```bash
gem install dotenv
```

3. Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

4. Configure your `.env` file with your API keys:
```env
OPENAI_API_KEY=sk-your-openai-api-key-here
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=-1001234567890
```

### Getting Telegram Bot Token and Chat ID

1. **Create a Telegram Bot:**
   - Open Telegram and search for [@BotFather](https://t.me/BotFather)
   - Send `/newbot` command
   - Follow the instructions to create your bot
   - Copy the bot token (looks like: `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`)

2. **Get Your Chat ID:**
   - Start a chat with your bot (send any message)
   - Open this URL in browser: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Look for `"chat":{"id":` in the JSON response
   - Copy the chat ID (can be positive or negative number)

   Or use [@userinfobot](https://t.me/userinfobot):
   - Send any message to @userinfobot
   - It will reply with your user/chat ID

## Usage

Run the script with your message as an argument:

```bash
ruby main.rb "your message here"
```

### Examples

```bash
# Example 1: Standard format
ruby main.rb "Halo, saya Budi 081234567890. Booking untuk hari Senin, 15 Januari jam 14:00"

# Example 2: Informal format
ruby main.rb "Pak, ini Andi. Nomor saya 0812-3456-7890, mau booking Jumat 17 Jan pukul 10 pagi"

# Example 3: Mixed format
ruby main.rb "Saya Romy +6281234567890, booking tanggal 20 Januari hari Rabu jam 3 sore"

# Example 4: Very casual
ruby main.rb "Halo kak, Dewi disini. HP: 08123456789. Mau booking besok Kamis jam 2 siang ya"
```

## Output

The script will:
1. Display extracted information in the terminal
2. Append the result to `result.txt`
3. Send a notification to your Telegram chat

### Terminal Output:
```
📱 Message Parser v1.0
==================================================

📩 Message: Halo, saya Budi 081234567890. Booking untuk hari Senin, 15 Januari jam 14:00

⚠️  Warning: TELEGRAM_BOT_TOKEN not set. Telegram notifications disabled.
Processing message...

📋 Extracted Information:
  📞 Phone: 081234567890
  📅 Date: Senin, 15 Januari 2026
  🕐 Time: 14:00
  👤 Name: Budi

✓ Data saved to result.txt
✓ Sent to Telegram

✅ Done!
```

### Telegram Message:
```
🔔 JADWAL SURVEY BARU

📅 Tanggal: Senin, 15 Januari 2026
🕐 Waktu: 14:00
👤 Nama: Budi
📞 No. HP: 081234567890

Processed at 14 January 2026, 10:30:45
```

### result.txt Format:
```
===== Processed at: 2026-01-14 10:30:45 =====
JADWAL SURVEY:
- Phone Number : 081234567890
- Date         : Senin, 15 Januari 2026
- Time         : 14:00
- Name         : Budi
==================================================
```

## Supported Message Formats

The AI can handle various formats:
- Phone: `081234567890`, `0812-3456-7890`, `+6281234567890`, `08123456789`
- Date: `15 Januari`, `Senin 15 Jan`, `tanggal 15`, `hari Senin`
- Time: `jam 14:00`, `pukul 2 siang`, `jam 10 pagi`, `3 sore`
- Name: `saya Budi`, `ini Andi`, `Nama saya Romy`, `Dewi disini`

## Error Handling

If the API key is missing:
```
❌ Fatal error: OPENAI_API_KEY environment variable not set
```

If message is empty:
```
❌ No message provided!
```

## Security Notes

- API key is stored in environment variable (not in code)
- Input is sanitized before sending to API
- Phone numbers are validated and truncated to 15 digits
- API timeout set to 30 seconds

## Requirements

- Ruby 2.7+
- OpenAI API key
- Internet connection

## Cost

Uses GPT-4o-mini model (very affordable):
- ~$0.00015 per message
- Typically <200 tokens per request

## Troubleshooting

**Issue**: `OPENAI_API_KEY environment variable not set`
- **Solution**: Make sure your `.env` file contains the correct API key

**Issue**: Telegram notifications not working
- **Solution**: 
  1. Check your `.env` file has both `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`
  2. Start a chat with your bot first (send any message)
  3. Make sure the bot token is correct
  4. Verify chat ID is correct (use `/getUpdates` API endpoint)

**Issue**: API timeout
- **Solution**: Check your internet connection

**Issue**: Extracted data is empty
- **Solution**: Make sure message contains relevant information

**Issue**: `cannot load such file -- dotenv`
- **Solution**: Run `gem install dotenv`

## License

MIT
