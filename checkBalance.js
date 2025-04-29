const { Web3 } = require("web3");
const fs = require("fs");

// Cấu hình RPC
const RPC_URL = "https://api.shardeum.org";
const web3 = new Web3(new Web3.providers.HttpProvider(RPC_URL));

// Đọc danh sách địa chỉ từ file text
const FILE_PATH = "./addresses.txt"; // Đổi đường dẫn file nếu cần

function readAddressesFromTxt(filePath) {
    if (!fs.existsSync(filePath)) {
        console.error("❌ File không tồn tại!");
        return [];
    }
    const data = fs.readFileSync(filePath, "utf-8");
    return data.split("\n").map(line => line.trim()).filter(line => line.length > 0);
}

// Lấy danh sách địa chỉ từ file
const addressesRaw = readAddressesFromTxt(FILE_PATH);

// Tách địa chỉ và tên từ danh sách
const addressList = addressesRaw.map(line => {
    const [address, name] = line.split(",");
    return { address, name };
});

// Hàm kiểm tra số dư
async function getBalance(address) {
    try {
        const balance = await web3.eth.getBalance(address);
        return parseFloat(web3.utils.fromWei(balance, "ether"));
    } catch (error) {
        console.error(`❌ Lỗi khi lấy số dư địa chỉ ${address}:`, error);
        return 0; // Trả về 0 nếu lỗi
    }
}

// Hàm căn chỉnh chuỗi (padding)
function padString(str, length, align = "left") {
    const padded = str.toString().substring(0, length); // Cắt ngắn nếu chuỗi dài hơn độ dài mong muốn
    if (align === "left") {
        return padded + " ".repeat(length - padded.length);
    } else {
        return " ".repeat(length - padded.length) + padded;
    }
}

// Kiểm tra số dư của từng địa chỉ và tính tổng
(async () => {
    if (addressList.length === 0) {
        console.log("⚠️ Không có địa chỉ nào trong file.");
        return;
    }
    console.log("������ Check balance...");
    // In tiêu đề cột
    console.log(
        `${padString("TÊN", 10)} ${padString("ĐỊA CHỈ", 42)} ${padString("SỐ DƯ", 10, "right")} MON`
    );
    console.log("-".repeat(65)); // Đường kẻ phân cách

    let totalBalance = 0; // Biến để tính tổng số dư
    for (const { address, name } of addressList) {
        const balance = await getBalance(address);
        totalBalance += balance; // Cộng dồn số dư
        console.log(
            `${padString(name, 10)} ${padString(address, 42)} ${padString(balance.toString(), 10, "right")} MON`
        );
    }

    // In hàng tổng số dư
    console.log("-".repeat(65)); // Đường kẻ phân cách
    console.log(
        `${padString("TỔNG", 10)} ${padString("", 42)} ${padString(totalBalance.toString(), 10, "right")} MON`
    );
})();