const { Web3 } = require("web3");
const fs = require("fs");

// Cấu hình RPC
const RPC_URL = "https://api.shardeum.org";
const web3 = new Web3(new Web3.providers.HttpProvider(RPC_URL));

// Đọc danh sách địa chỉ từ file text
const FILE_PATH = "./addresses-bk.txt"; // Đổi đường dẫn file nếu cần

function readAddressesFromTxt(filePath) {
    if (!fs.existsSync(filePath)) {
        console.error("❌ File không tồn tại!");
        return [];
    }
    const data = fs.readFileSync(filePath, "utf-8");
    return data.split("\n").map(line => line.trim()).filter(line => line.length > 0);
}

// Lấy danh sách địa chỉ từ file
const addresses = readAddressesFromTxt(FILE_PATH);

// Hàm kiểm tra số dư
async function getBalance(address) {
    try {
        const balance = await web3.eth.getBalance(address);
        console.log(`[Balance ${address}]:`, web3.utils.fromWei(balance, "ether"), "MON");
    } catch (error) {
        console.error(`❌ Lỗi khi lấy số dư địa chỉ ${address}:`, error);
    }
}

// Kiểm tra số dư của từng địa chỉ
(async () => {
    if (addresses.length === 0) {
        console.log("⚠️ Không có địa chỉ nào trong file.");
        return;
    }
    console.log("🔎 Check balance...");
    for (const address of addresses) {
        await getBalance(address);
    }
})();

