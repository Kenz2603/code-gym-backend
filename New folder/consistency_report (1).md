# HealthSync – Consistency / Gap Analysis

Thiết kế cơ sở dữ liệu cũ của HealthSync có ba điểm vênh nghiêm trọng với quy trình nghiệp vụ. Thứ nhất, bảng `Appointments` dùng `is_active` kiểu Boolean nên chỉ biểu diễn được hai trạng thái, trong khi vòng đời lịch hẹn thực tế gồm `PENDING`, `CONFIRMED`, `CHECKED_IN`, `COMPLETED` và `CANCELLED`. Điều này làm hệ thống không thể xác định chính xác lịch hẹn đang ở bước nào của quy trình.

Thứ hai, thiết kế cũ không có các trường `deposit_amount`, `penalty_fee` và `cancel_reason`. Vì vậy hệ thống không thể lưu tiền cọc, khoản phạt khi bệnh nhân hủy sau xác nhận, cũng như lý do hủy. Đây là lỗ hổng trực tiếp ảnh hưởng đến đối soát tài chính và khả năng kiểm tra lịch sử giao dịch.

Thứ ba, cơ sở dữ liệu không có bảng `Prescriptions`, nên không thể lưu đơn thuốc sau khi lịch hẹn hoàn tất. Thiết kế mới bổ sung bảng này và liên kết với `Appointments` bằng khóa ngoại. Đồng thời, trigger ở tầng cơ sở dữ liệu chỉ cho phép tạo đơn thuốc khi lịch hẹn có trạng thái `COMPLETED`, giúp ngăn dữ liệu phi logic và tăng tính toàn vẹn giữa quy trình nghiệp vụ và dữ liệu lưu trữ.
