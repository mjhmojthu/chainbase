const { ethers } = require("ethers");
require("dotenv").config();

// Cấu hình RPC và Ví
const RPC_URL = "https://testnet-rpc.monad.xyz";
const KHOA_BI_MAT = process.env.PRIVATE_KEY;
const nhaCungCap = new ethers.JsonRpcProvider(RPC_URL);
const vi = new ethers.Wallet(KHOA_BI_MAT, nhaCungCap);

// Địa chỉ hợp đồng lấy từ giao dịch thực tế
const DIA_CHI_HOP_DONG = "0xe1d2439b75fb9746E7Bc6cB777Ae10AA7f7ef9c5";

// Function selector của hàm stake và unstake
const FUNCTION_SELECTOR_STAKE = "0x1c3477dd"; // Từ script stake ban đầu
const FUNCTION_SELECTOR_UNSTAKE = "0xb17033b6"; // Từ giao dịch thành công

// ABI tối thiểu để kiểm tra số dư (thử cả balanceOf và stakedBalance)
const ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function stakedBalance(address) view returns (uint256)",
];
const hopDong = new ethers.Contract(DIA_CHI_HOP_DONG, ABI, nhaCungCap);

// Tạo dữ liệu hex động dựa trên địa chỉ ví
const diaChiVi = vi.address;
console.log(`📍 Địa chỉ ví: ${diaChiVi}`);

// Mã hóa địa chỉ ví thành 32 byte (64 ký tự hex)
const diaChiViHex = diaChiVi.replace("0x", "").toLowerCase().padStart(64, "0");

// Số lượng MON để stake và unstake
const SO_LUONG_STAKE = "0.01"; // Từ script stake ban đầu
const SO_LUONG_UNSTAKE = "0.008"; // Từ yêu cầu trước đó

// Giả định số dư tối thiểu cần chừa lại (0.002 MON)
const SO_DU_TOI_THIEU = "0.002";

// Hàm tạo thời gian delay ngẫu nhiên từ 2 đến 5 phút (120 đến 300 giây)
function getRandomDelay() {
  const minDelay = 120; // 2 phút
  const maxDelay = 300; // 5 phút
  const delayInSeconds = Math.floor(Math.random() * (maxDelay - minDelay + 1)) + minDelay;
  return delayInSeconds * 1000; // Chuyển sang mili giây
}

// Hàm stakeMON
async function stakeMON() {
  try {
    // Kiểm tra số dư của ví trước khi stake
    const soDu = await nhaCungCap.getBalance(vi.address);
    const soDuMON = ethers.formatEther(soDu);
    console.log(`💰 Số dư hiện tại của ví: ${soDuMON} MON`);

    const soLuongCanStake = ethers.parseEther(SO_LUONG_STAKE);

    // Tạo dữ liệu hex: function selector + tham số 0 + địa chỉ ví
    const DU_LIEU_HEX =
      FUNCTION_SELECTOR_STAKE +
      "0000000000000000000000000000000000000000000000000000000000000000" +
      diaChiViHex;
    console.log(`📜 Dữ liệu hex (stake): ${DU_LIEU_HEX}`);

    // Thực hiện giao dịch stake
    const giaoDich = await vi.sendTransaction({
      to: DIA_CHI_HOP_DONG,
      value: soLuongCanStake,
      data: DU_LIEU_HEX,
      gasLimit: 100000n,
    });

    console.log(`🔹 Đang stake MON... Mã giao dịch: ${giaoDich.hash}`);
    const bienNhan = await giaoDich.wait();
    console.log(`✅ Stake thành công! Giao dịch: ${bienNhan.hash}`);
    console.log(
      `📊 Chi tiết giao dịch: https://testnet.monadexplorer.com/tx/${bienNhan.hash}`
    );
  } catch (loi) {
    console.error("❌ Lỗi khi stake MON:", loi.message);
    throw loi; // Ném lỗi để dừng script nếu stake thất bại
  }
}

// Hàm unstakeMON
async function unstakeMON() {
  try {
    // Kiểm tra số dư của ví trong hợp đồng
    let soDuTrongHopDong;
    try {
      soDuTrongHopDong = await hopDong.balanceOf(vi.address);
    } catch (error) {
      console.log("⚠️ Không thể gọi balanceOf, thử stakedBalance...");
      soDuTrongHopDong = await hopDong.stakedBalance(vi.address);
    }
    const soDuMON = ethers.formatEther(soDuTrongHopDong);
    console.log(`💰 Số dư của ví trong hợp đồng: ${soDuMON} MON`);

    // Kiểm tra số dư bằng cách so sánh với 0
    if (soDuTrongHopDong === 0n || soDuTrongHopDong === BigInt(0)) {
      console.log("⚠️ Số dư trong hợp đồng bằng 0, không thể unstake.");
      return;
    }

    // Chuyển số lượng unstake (0.008 MON) thành Wei (BigInt)
    const soLuongUnstakeWei = ethers.parseEther(SO_LUONG_UNSTAKE);
    console.log(`🔢 Số lượng unstake: ${SO_LUONG_UNSTAKE} MON (${soLuongUnstakeWei} Wei)`);

    // Kiểm tra xem số dư có đủ để unstake 0.008 MON không
    if (soDuTrongHopDong < soLuongUnstakeWei) {
      console.log("⚠️ Số dư không đủ để unstake 0.008 MON.");
      return;
    }

    // Kiểm tra số dư tối thiểu sau khi unstake
    const soDuToiThieuWei = ethers.parseEther(SO_DU_TOI_THIEU);
    const soDuConLai = soDuTrongHopDong - soLuongUnstakeWei;
    const soDuConLaiMON = ethers.formatEther(soDuConLai);
    console.log(`💰 Số dư còn lại sau khi unstake: ${soDuConLaiMON} MON`);

    if (soDuConLai < soDuToiThieuWei) {
      console.log(`⚠️ Số dư còn lại (${soDuConLaiMON} MON) nhỏ hơn số dư tối thiểu yêu cầu (${SO_DU_TOI_THIEU} MON).`);
      return;
    }

    // Kiểm tra số dư MON của ví trên blockchain
    const soDuVi = await nhaCungCap.getBalance(vi.address);
    const soDuViMON = ethers.formatEther(soDuVi);
    console.log(`💰 Số dư hiện tại của ví: ${soDuViMON} MON`);

    // Mã hóa số lượng unstake thành 32 byte (64 ký tự hex)
    const soLuongHex = soLuongUnstakeWei.toString(16).padStart(64, "0");

    // Tạo dữ liệu hex: function selector + số lượng
    const DU_LIEU_HEX = FUNCTION_SELECTOR_UNSTAKE + soLuongHex;
    console.log(`📜 Dữ liệu hex (unstake): ${DU_LIEU_HEX}`);

    // Thực hiện giao dịch unstake
    const giaoDich = await vi.sendTransaction({
      to: DIA_CHI_HOP_DONG,
      data: DU_LIEU_HEX,
      gasLimit: 100000n,
    });

    console.log(`🔹 Đang unstake MON... Mã giao dịch: ${giaoDich.hash}`);
    const bienNhan = await giaoDich.wait();
    console.log(`✅ Unstake thành công! Giao dịch: ${bienNhan.hash}`);
    console.log(
      `📊 Chi tiết giao dịch: https://testnet.monadexplorer.com/tx/${bienNhan.hash}`
    );
  } catch (loi) {
    console.error("❌ Lỗi khi unstake MON:", loi.message);
  }
}

// Hàm chính để chạy stake và unstake với delay
async function main() {
  try {
    // Chạy stake
    await stakeMON();

    // Tạo thời gian delay ngẫu nhiên từ 2 đến 5 phút
    const delay = getRandomDelay();
    console.log(`⏳ Đợi ${delay / 1000} giây trước khi unstake...`);

    // Đợi trước khi unstake
    await new Promise((resolve) => setTimeout(resolve, delay));

    // Chạy unstake
    await unstakeMON();
  } catch (loi) {
    console.error("❌ Lỗi trong quá trình thực thi:", loi.message);
  }
}

// Chạy script
main();
