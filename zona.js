const { ethers } = require("ethers");
require("dotenv").config();

// Cấu hình RPC và Wallet
const RPC_URL = "https://testnet-rpc.monad.xyz";
const PRIVATE_KEY = process.env.PRIVATE_KEY || "YOUR_PRIVATE_KEY_HERE";
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Địa chỉ contract (lấy từ MetaMask, cần đầy đủ)
const CONTRACT_ADDRESS = "0x2c68cda200000000000000000000000000000000"; // Cập nhật nếu cần

// Input data từ giao dịch
const INPUT_DATA = "0x2c68cda2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000006f05b59d3b20000000000000000000000000000000000000000000000000000000000000000000973696e6761706f72650000000000000000000000000000000000000000000000";

// Hàm thực hiện giao dịch nhiều lần
async function executeTransaction(count) {
  try {
    // Kiểm tra số lần hợp lệ
    if (!Number.isInteger(count) || count <= 0) {
      throw new Error("Số lần thực hiện phải là số nguyên dương.");
    }

    console.log(`Chuẩn bị thực hiện ${count} giao dịch...`);

    // Gửi giao dịch trực tiếp (không cần ABI vì dùng fallback)
    for (let i = 1; i <= count; i++) {
      console.log(`Giao dịch thứ ${i}/${count}...`);

      // Gửi giao dịch với input data và 0.5 MON
      const tx = await wallet.sendTransaction({
        to: CONTRACT_ADDRESS,
        value: ethers.parseEther("0.5"), // Gửi 0.5 MON
        data: INPUT_DATA, // Dùng input data gốc
      });

      console.log(`Giao dịch thứ ${i} đã được gửi! Hash: ${tx.hash}`);

      // Chờ giao dịch được xác nhận
      const receipt = await tx.wait();
      console.log(
        `Giao dịch thứ ${i} đã được xác nhận! Block: ${receipt.blockNumber}`
      );
    }

    console.log(`✅ Hoàn tất ${count} giao dịch!`);
  } catch (error) {
    console.error("❌ Lỗi khi thực hiện giao dịch:", error.message);
    if (error.data) {
      console.error("Dữ liệu lỗi:", error.data);
    }
  }
}

// Hàm chính: Lấy số lần thực hiện từ command line
async function main() {
  try {
    // Lấy số lần từ tham số dòng lệnh (node script.js 5)
    const args = process.argv.slice(2);
    const txCount = parseInt(args[0]);

    if (isNaN(txCount) || txCount <= 0) {
      throw new Error(
        "Vui lòng cung cấp số lần thực hiện hợp lệ (ví dụ: node script.js 5)."
      );
    }

    console.log(`Địa chỉ ví: ${wallet.address}`);
    await executeTransaction(txCount);
  } catch (error) {
    console.error("Lỗi trong chương trình:", error.message);
    process.exit(1);
  }
}

// Chạy chương trình
main();
