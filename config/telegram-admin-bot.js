// KhongAI Telegram Admin Bot
// Allows admins to control and configure the AI via Telegram commands

const TelegramBot = require('node-telegram-bot-api');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

// Configuration
const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const ADMIN_IDS = (process.env.ADMIN_USER_IDS || '').split(',').map(id => id.trim());
const CONFIG_PATH = process.env.KHONGAI_CONFIG_PATH || '/home/node/.khongai';
const LOG_PATH = path.join(CONFIG_PATH, 'logs', 'admin-bot.log');

// Ensure log directory exists
const logDir = path.dirname(LOG_PATH);
if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
}

// Logger function
function log(message, level = 'INFO') {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] [${level}] ${message}\n`;
    fs.appendFileSync(LOG_PATH, logMessage);
    console.log(logMessage.trim());
}

// Check if user is admin (supports both username and numeric ID)
function isAdmin(userId, username) {
    for (const admin of ADMIN_IDS) {
        // Check by numeric ID
        if (admin === String(userId)) return true;
        // Check by username (with or without @)
        if (username && admin.toLowerCase() === username.toLowerCase()) return true;
        if (username && admin.toLowerCase() === `@${username.toLowerCase()}`) return true;
        // Check by @username format
        if (admin === `@${username}`) return true;
    }
    return false;
}

// Execute command with timeout
async function executeCommand(command, timeout = 30000) {
    try {
        const { stdout, stderr } = await execPromise(command, { timeout });
        return { success: true, output: stdout, error: stderr };
    } catch (error) {
        return { success: false, output: error.stdout, error: error.stderr || error.message };
    }
}

// Read OpenClaw config
function readOpenClawConfig() {
    const configFile = path.join(CONFIG_PATH, 'openclaw.json');
    if (fs.existsSync(configFile)) {
        try {
            return JSON.parse(fs.readFileSync(configFile, 'utf8'));
        } catch (e) {
            return null;
        }
    }
    return null;
}

// Write OpenClaw config
function writeOpenClawConfig(config) {
    const configFile = path.join(CONFIG_PATH, 'openclaw.json');
    fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
    return true;
}

// Update AI model
async function updateAIModel(modelName) {
    const config = readOpenClawConfig();
    if (!config) return false;
    
    if (!config.ai) config.ai = {};
    if (!config.ai.ollama) config.ai.ollama = {};
    
    config.ai.ollama.model = modelName;
    writeOpenClawConfig(config);
    
    return true;
}

// Get system status
async function getSystemStatus() {
    const status = {};
    
    // Check OpenClaw
    try {
        const response = await fetch('http://localhost:18789/health');
        status.openclaw = response.ok ? 'healthy' : 'unhealthy';
    } catch (e) {
        status.openclaw = 'not running';
    }
    
    // Get memory usage
    const memUsage = await executeCommand('free -h');
    status.memory = memUsage.output.split('\n')[1] || 'unknown';
    
    // Get disk usage
    const diskUsage = await executeCommand('df -h /home/node/.khongai');
    status.disk = diskUsage.output.split('\n')[1] || 'unknown';
    
    // Get OpenClaw version
    const version = await executeCommand('cat /app/openclaw-commit.txt 2>/dev/null || echo "unknown"');
    status.version = version.output.trim().substring(0, 8);
    
    return status;
}

// Get recent logs
async function getRecentLogs(lines = 50) {
    const logFile = path.join(CONFIG_PATH, 'logs', 'openclaw.log');
    if (fs.existsSync(logFile)) {
        const content = fs.readFileSync(logFile, 'utf8');
        const logLines = content.split('\n').filter(l => l.trim());
        return logLines.slice(-lines).join('\n');
    }
    return 'No logs found';
}

// Restart services
async function restartServices() {
    // The start.sh script handles restart
    await executeCommand('pkill -f "node.*openclaw" || true');
    return true;
}

// Main bot logic
async function startBot() {
    if (!BOT_TOKEN) {
        log('TELEGRAM_BOT_TOKEN not set', 'ERROR');
        return;
    }
    
    const bot = new TelegramBot(BOT_TOKEN, { polling: true });
    
    log('KhongAI Admin Bot started');
    
    // Welcome message for new chats
    bot.onText(/\/start/, (msg) => {
        const chatId = msg.chat.id;
        const userId = msg.from.id;
        const username = msg.from.username;
        
        if (isAdmin(userId, username)) {
            bot.sendMessage(chatId, 
                `🤖 *KhongAI Admin Bot*\n\n` +
                `Welcome back, *${msg.from.first_name || 'Admin'}*!\n\n` +
                `📋 *Available Commands:*\n` +
                `/status - Check system status\n` +
                `/logs [lines] - View recent logs\n` +
                `/restart - Restart KhongAI\n` +
                `/config - View current config\n` +
                `/model <name> - Change AI model\n` +
                `/models - List available models\n` +
                `/help - Show all commands\n` +
                `/stats - View usage statistics\n` +
                `/health - Detailed health check\n\n` +
                `⚠️ *Dangerous Commands:*\n` +
                `/exec <cmd> - Execute shell command (requires confirmation)`,
                { parse_mode: 'Markdown' }
            );
        } else {
            bot.sendMessage(chatId, 
                `⚠️ *Unauthorized Access*\n\n` +
                `You are not authorized to use this bot.\n` +
                `Please contact @khongtk or @renyu4444 for access.`,
                { parse_mode: 'Markdown' }
            );
        }
    });
    
    // Status command
    bot.onText(/\/status/, async (msg) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        await bot.sendChatAction(chatId, 'typing');
        
        const status = await getSystemStatus();
        const config = readOpenClawConfig();
        const currentModel = config?.ai?.ollama?.model || 'llama2';
        
        bot.sendMessage(chatId,
            `📊 *KhongAI System Status*\n\n` +
            `🤖 OpenClaw: ${status.openclaw}\n` +
            `🦙 AI Model: ${currentModel}\n` +
            `📦 Version: ${status.version}\n` +
            `💾 Memory: ${status.memory}\n` +
            `💿 Disk: ${status.disk}\n` +
            `🕐 Uptime: ${Math.floor(process.uptime())}s`,
            { parse_mode: 'Markdown' }
        );
    });
    
    // Logs command
    bot.onText(/\/logs(?:\s+(\d+))?/, async (msg, match) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        const lines = match[1] ? parseInt(match[1]) : 50;
        
        await bot.sendChatAction(chatId, 'typing');
        const logs = await getRecentLogs(lines);
        
        if (logs.length > 4000) {
            // Send as file if too long
            const logFile = path.join(CONFIG_PATH, 'temp-logs.txt');
            fs.writeFileSync(logFile, logs);
            await bot.sendDocument(chatId, logFile, { caption: `Last ${lines} lines of logs` });
            fs.unlinkSync(logFile);
        } else {
            bot.sendMessage(chatId, `📝 *Recent Logs (last ${lines} lines)*\n\`\`\`\n${logs}\n\`\`\``, { parse_mode: 'Markdown' });
        }
    });
    
    // Restart command
    bot.onText(/\/restart/, async (msg) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        await bot.sendMessage(chatId, '🔄 Restarting KhongAI...');
        
        await restartServices();
        
        setTimeout(async () => {
            const status = await getSystemStatus();
            bot.sendMessage(chatId, `✅ KhongAI restarted!\nStatus: ${status.openclaw}`);
        }, 5000);
    });
    
    // Config command
    bot.onText(/\/config/, async (msg) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        const config = readOpenClawConfig();
        
        if (config) {
            const configStr = JSON.stringify(config, null, 2);
            if (configStr.length > 4000) {
                const configFile = path.join(CONFIG_PATH, 'temp-config.json');
                fs.writeFileSync(configFile, configStr);
                await bot.sendDocument(chatId, configFile, { caption: 'Current configuration' });
                fs.unlinkSync(configFile);
            } else {
                bot.sendMessage(chatId, `📋 *Current Configuration*\n\`\`\`json\n${configStr}\n\`\`\``, { parse_mode: 'Markdown' });
            }
        } else {
            bot.sendMessage(chatId, '❌ No configuration found');
        }
    });
    
    // Change model command
    bot.onText(/\/model\s+(.+)/, async (msg, match) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        const modelName = match[1].trim();
        
        await bot.sendMessage(chatId, `🦙 Switching to model: ${modelName}...`);
        
        const success = await updateAIModel(modelName);
        
        if (success) {
            bot.sendMessage(chatId, `✅ Model changed to ${modelName}\nRestarting to apply changes...`);
            await restartServices();
        } else {
            bot.sendMessage(chatId, `❌ Failed to change model to ${modelName}`);
        }
    });
    
    // List models command (if Ollama is available)
    bot.onText(/\/models/, async (msg) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        
        try {
            const { stdout } = await execPromise('ollama list 2>/dev/null || echo "Ollama not available"');
            bot.sendMessage(chatId, `📦 *Available Models*\n\`\`\`\n${stdout}\n\`\`\``, { parse_mode: 'Markdown' });
        } catch (e) {
            bot.sendMessage(chatId, '❌ Could not fetch model list');
        }
    });
    
    // Stats command
    bot.onText(/\/stats/, async (msg) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        
        // Get conversation stats from logs
        const logs = await getRecentLogs(1000);
        const userMessages = (logs.match(/User message:/g) || []).length;
        const aiResponses = (logs.match(/AI response:/g) || []).length;
        
        bot.sendMessage(chatId,
            `📈 *KhongAI Usage Statistics*\n\n` +
            `💬 User Messages: ${userMessages}\n` +
            `🤖 AI Responses: ${aiResponses}\n` +
            `🔄 Success Rate: ${aiResponses > 0 ? Math.round((aiResponses / userMessages) * 100) : 0}%\n` +
            `📊 Total Interactions: ${userMessages + aiResponses}`,
            { parse_mode: 'Markdown' }
        );
    });
    
    // Execute shell command (dangerous - requires confirmation)
    let pendingCommand = null;
    
    bot.onText(/\/exec\s+(.+)/, async (msg, match) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        const command = match[1];
        
        pendingCommand = { chatId, command, userId };
        
        bot.sendMessage(chatId, 
            `⚠️ *DANGEROUS OPERATION*\n\n` +
            `You are about to execute:\n\`${command}\`\n\n` +
            `Type /confirm to proceed or /cancel to abort.\n` +
            `*This command will expire in 30 seconds.*`,
            { parse_mode: 'Markdown' }
        );
        
        // Set timeout
        setTimeout(() => {
            if (pendingCommand && pendingCommand.chatId === chatId) {
                pendingCommand = null;
                bot.sendMessage(chatId, '⏰ Command confirmation timeout');
            }
        }, 30000);
    });
    
    // Confirm command
    bot.onText(/\/confirm/, async (msg) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        
        if (pendingCommand && pendingCommand.chatId === chatId && pendingCommand.userId === userId) {
            const { command } = pendingCommand;
            pendingCommand = null;
            
            await bot.sendMessage(chatId, `⚙️ Executing: \`${command}\`\nPlease wait...`, { parse_mode: 'Markdown' });
            
            const result = await executeCommand(command);
            
            if (result.success) {
                const output = result.output.substring(0, 4000);
                bot.sendMessage(chatId, `✅ *Command executed*\n\`\`\`\n${output || '(no output)'}\n\`\`\``, { parse_mode: 'Markdown' });
            } else {
                const error = result.error.substring(0, 4000);
                bot.sendMessage(chatId, `❌ *Command failed*\n\`\`\`\n${error}\n\`\`\``, { parse_mode: 'Markdown' });
            }
        } else {
            bot.sendMessage(chatId, 'No pending command to confirm');
        }
    });
    
    // Cancel command
    bot.onText(/\/cancel/, async (msg) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        
        if (pendingCommand && pendingCommand.chatId === chatId) {
            pendingCommand = null;
            bot.sendMessage(chatId, '❌ Command cancelled');
        }
    });
    
    // Help command
    bot.onText(/\/help/, (msg) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        bot.sendMessage(msg.chat.id,
            `*🤖 KhongAI Admin Commands*\n\n` +
            `🟢 *Basic Commands*\n` +
            `/status - Check system health\n` +
            `/logs [lines] - View logs (default 50)\n` +
            `/restart - Restart KhongAI\n` +
            `/config - View current configuration\n\n` +
            `🟡 *AI Control*\n` +
            `/model <name> - Change AI model\n` +
            `/models - List available models\n\n` +
            `🔵 *Monitoring*\n` +
            `/stats - View usage statistics\n` +
            `/health - Detailed health check\n\n` +
            `🔴 *Dangerous* (use with caution)\n` +
            `/exec <cmd> - Execute shell command (requires confirmation)\n\n` +
            `📝 *Examples:*\n` +
            `/model mistral\n` +
            `/logs 100\n` +
            `/exec docker ps\n` +
            `/exec docker logs khongai --tail 20`,
            { parse_mode: 'Markdown' }
        );
    });
    
    // Health check
    bot.onText(/\/health/, async (msg) => {
        const userId = msg.from.id;
        const username = msg.from.username;
        if (!isAdmin(userId, username)) return;
        
        const chatId = msg.chat.id;
        const status = await getSystemStatus();
        const config = readOpenClawConfig();
        
        const healthMsg = 
            `🏥 *KhongAI Health Check*\n\n` +
            `✓ OpenClaw: ${status.openclaw === 'healthy' ? '✅' : '❌'} ${status.openclaw}\n` +
            `✓ Memory: ${status.memory.includes('available') ? '✅' : '⚠️'}\n` +
            `✓ Disk Space: ${status.disk.includes('available') ? '✅' : '⚠️'}\n` +
            `✓ Config: ${config ? '✅ Valid' : '❌ Missing'}\n` +
            `✓ Bot Token: ${BOT_TOKEN ? '✅ Configured' : '❌ Missing'}\n` +
            `✓ Admins: ${ADMIN_IDS.length} configured\n\n` +
            `Last Check: ${new Date().toISOString()}`;
        
        bot.sendMessage(chatId, healthMsg, { parse_mode: 'Markdown' });
    });
    
    // Handle errors
    bot.on('error', (error) => {
        log(`Bot error: ${error.message}`, 'ERROR');
    });
    
    log('KhongAI Admin Bot is ready and listening for commands');
}

// Start the bot
startBot().catch(error => {
    log(`Failed to start bot: ${error.message}`, 'ERROR');
});

module.exports = { startBot };