#!/usr/bin/env node
// run_storage.js - Script Node.js chạy 0g-storage-client cho nhiều private key
// Lưu file này là run_storage.js và chạy bằng: node run_storage.js

const fs = require('fs');
const { exec } = require('child_process');
const readline = require('readline');
const path = require('path');

// ====== CẤU HÌNH ======
const KEYS_FILE   = path.join(__dirname, 'privatekeys.txt');
const CLIENT_BIN  = path.join(__dirname, '0g-storage-client');
const UPLOAD_URL  = 'http://37.27.60.37:8545';
const NODE_URL    = 'http://0.0.0.0:5678';
const FILE_NAME   = 'tmp123456';
const GAS_LIMIT   = '500000';
const GEN_ARGS    = ['gen', '--size', '100', '--overwrite'];
const UPLOAD_ARGS = [
  'upload',
  '--url', UPLOAD_URL,
  '--key', null,
  '--node', NODE_URL,
  '--file', FILE_NAME,
  '--gas-limit', GAS_LIMIT
];
// ====================

// Kiểm tra file privatekeys.txt
if (!fs.existsSync(KEYS_FILE)) {
  console.error(`❌ File not found: ${KEYS_FILE}`);
  process.exit(1);
}

// Đọc lines và loại bỏ blank/comment
const lines = fs.readFileSync(KEYS_FILE, 'utf8')
  .split(/\r?\n/)
  .map(l => l.trim())
  .filter(l => l && !l.startsWith('#'));

// Thực thi command với prefix tên
function runCommand(name, command, args) {
  return new Promise((resolve, reject) => {
    const cmdString = `${command} ${args.map(a => (a === null ? '' : a)).join(' ')}`;
    const proc = exec(cmdString, { cwd: __dirname, shell: true });
    proc.stdout.on('data', d => process.stdout.write(`[${name}] ${d}`));
    proc.stderr.on('data', d => process.stderr.write(`[${name}] ${d}`));
    proc.on('close', code => code === 0 ? resolve() : reject(new Error(`Exit code ${code}`)));
  });
}

// Delay helper
const delay = ms => new Promise(res => setTimeout(res, ms));

// Prompt số lần lặp
const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
rl.question('Nhập số lần lặp cho mỗi key: ', async input => {
  rl.close();
  const runs = parseInt(input, 10);
  if (isNaN(runs) || runs < 1) {
    console.error('❌ Vui lòng nhập số nguyên >= 1');
    process.exit(1);
  }

  console.log(`🔄 Chạy ${runs} lần, mỗi lần xử lý ${lines.length} key.`);

  for (let run = 1; run <= runs; run++) {
    console.log(`\n🔁 Vòng lặp ${run}/${runs}`);
    for (let i = 0; i < lines.length; i++) {
      const [privateKey, name] = lines[i].split(',');
      console.log(`🔄 [${i + 1}/${lines.length}] Key: ${name}`);
      try {
        // GEN storage
        await runCommand(name, CLIENT_BIN, GEN_ARGS);
        console.log(`[${name}] Chờ 10s...`);
        await delay(10000);

        // UPLOAD storage
        const uploadArgs = [...UPLOAD_ARGS];
        // Đặt privateKey vào đúng vị trí sau --key
        const keyIndex = uploadArgs.findIndex(arg => arg === '--key');
        if (keyIndex !== -1) uploadArgs[keyIndex + 1] = privateKey;
        await runCommand(name, CLIENT_BIN, uploadArgs);
        console.log(`[${name}] Chờ 10s...`);
        await delay(10000);
      } catch (err) {
        console.error(`❌ [${name}] Lỗi: ${err.message}`);
      }
    }
  }

  console.log('🏁 Hoàn thành tất cả vòng lặp.');
});

