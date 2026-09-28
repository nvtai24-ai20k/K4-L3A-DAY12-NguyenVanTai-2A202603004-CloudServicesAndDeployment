# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Văn Tài  Mã học viên: 2A202603004

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Giả sử trên Railway mình quên set `AGENT_API_KEY` cho service `agent`. Nếu
> có mặc định `"changeme"`, container vẫn khởi động, `/health` vẫn 200, Railway
> báo deploy thành công — nhưng `/ask` giờ được bảo vệ bằng một khóa ai cũng
> đoán được (nó nằm công khai trong repo). Bot quét endpoint gọi vào, mỗi request
> là tiền LLM của mình, và mình chỉ phát hiện khi nhìn hóa đơn. Không có mặc định
> thì `Settings()` ném `ValidationError` ngay lúc khởi động, container chết,
> healthcheck fail, deploy đỏ — lỗi hiện ra đúng lúc mình đang nhìn màn hình
> deploy, sửa bằng cách thêm biến rồi deploy lại, chưa ai kịp lợi dụng.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thật từ `docker compose logs agent` khi gọi `/ask`:
>
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T08:10:37.499517+00:00", "user_id": "rl-1937", "tokens_in": 302, "tokens_out": 43, "cost_usd": 7.11e-05}
> ```
>
> 1. **Lọc và cộng theo trường**: gom mọi dòng `event == "ask_completed"` rồi
>    cộng `cost_usd` theo `user_id` để biết user nào tiêu nhiều tiền nhất hôm nay.
>    Với `print("đã trả lời xong")` không có user, không có chi phí, không làm được.
> 2. **Đếm theo thời gian để cảnh báo**: nhờ `timestamp` và `level`, log platform
>    đếm được số dòng `level == "error"` trong 5 phút qua và bắn cảnh báo khi tỷ lệ
>    lỗi vượt ngưỡng. Chuỗi tự do thì phải regex đoán mò, đổi câu chữ là hỏng.
>
> Railway còn tự nhận dạng JSON một dòng và tách thành các trường
> `event=... service=...` khi xem bằng `railway logs`.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.73 GB (~1770 MB) |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Bản multi-stage nhỏ hơn khoảng 6,5 lần (1.73 GB → 271 MB). Phần chênh lệch ~1.5 GB
> là những thứ chỉ cần lúc build hoặc không bao giờ cần khi chạy:
> - Base image `python:3.11` bản đầy đủ mang theo gcc, header C, git, các thư viện
>   `-dev` và nhiều gói Debian; `python:3.11-slim` bỏ hết những thứ đó.
> - Bản 1 stage `COPY . .` nên kéo cả `tests/`, tài liệu `.md`, `.git`... vào
>   image (lúc đó `.dockerignore` chỉ loại `.git`, `.gitignore`).
> - `pip install` không có `--no-cache-dir` nên cache pip nằm lại trong layer.
>
> Bản multi-stage chỉ copy `/install` (thư viện đã cài) từ stage `builder` sang
> stage `runtime` slim, cộng `app/` và `utils/` — nên còn 271 MB.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Mình đổi một ký tự trong `app/main.py` (`SERVICE_VERSION` "1.0.0" → "1.0.1")
> rồi build lại. Kết quả thật: `FROM`, `WORKDIR`, `COPY requirements.txt`,
> `RUN pip install`, `COPY --from=builder`, `RUN useradd` đều `CACHED`; chỉ hai
> layer `COPY app ./app` và `COPY utils ./utils` chạy lại. Tổng thời gian build
> khoảng 3 giây.
>
> Nếu đặt `COPY . .` trước `RUN pip install` thì layer `COPY . .` đổi checksum vì
> `main.py` đổi, và Docker hủy cache từ layer đó trở xuống — `pip install` chạy
> lại toàn bộ, tải lại tất cả thư viện mỗi lần sửa một dấu phẩy. Lần build đầu
> không có cache của mình mất vài phút, nên khác biệt là vài giây so với vài phút
> cho mỗi lần sửa code.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: code Python có lỗ hổng (ví dụ deserialize dữ liệu không tin cậy,
> hay một thư viện bị lỗi RCE) → kẻ tấn công chạy được lệnh shell trong container
> → vì process chạy bằng root (uid 0) nên họ có toàn quyền trong container: đọc
> mọi file, cài công cụ → uid 0 trong container cũng là uid 0 trên kernel của
> host; chỉ cần thêm một lỗ hổng kernel/runtime, hoặc container mount nhầm
> `docker.sock` hay thư mục host, là họ thoát ra và thành root trên máy host.
>
> `USER appuser` cắt chuỗi ở bước thứ ba: mình kiểm tra `docker compose exec agent id`
> ra `uid=10001(appuser)`. Kẻ tấn công vào được cũng chỉ là user thường, không ghi
> được file hệ thống, không cài gói, và thoát khỏi container thì cũng chỉ là
> uid 10001 không có quyền gì trên host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Tối đa **20 request trong khoảng 2 giây**. Cách làm: gửi 10 request lúc
> 10:00:59 — vẫn trong hạn mức của phút 10:00. Đến 10:01:00 bộ đếm reset về 0,
> gửi tiếp 10 request lúc 10:01:00–10:01:01 — hợp lệ với phút mới. Tổng 20
> request trong 2 giây, gấp đôi hạn mức mà vẫn "đúng luật".
>
> Với cửa sổ trượt, lúc 10:01:01 hệ thống đếm các request trong 60 giây tính
> ngược từ thời điểm đó, vẫn thấy 10 request lúc 10:00:59 nên chặn ngay request
> thứ 11. Mình kiểm tra trên bản deploy: 15 request liên tiếp cùng `X-User-Id`
> ra `200 ×10` rồi `429 ×5`.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit giới hạn **số lượng request theo thời gian** (10/phút, cửa sổ 60s).
> Cost guard giới hạn **tổng số tiền theo tháng** (10 USD/user, key
> `cost:<user>:<YYYY-MM>`). Một cái chống spam/tốc độ, một cái chống cháy ngân sách.
>
> - **Rate limit cho qua, cost guard chặn**: user gửi đều 5 request/phút — dưới
>   hạn mức — nhưng mỗi request là một prompt 50.000 token kèm lịch sử dài. Sau
>   vài ngày tổng chi vượt 10 USD, cost guard trả 402 dù tốc độ gọi rất chậm.
> - **Cost guard cho qua, rate limit chặn**: user mới trong tháng (chi tiêu gần
>   0) chạy script gửi 15 câu ngắn trong vài giây. Chi phí chỉ vài phần trăm cent,
>   còn xa ngân sách, nhưng từ request thứ 11 rate limit trả 429 — đúng như mình
>   thấy khi test (`200 ×10`, `429 ×5`).

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Theo thứ tự:
> 1. Redis mất kết nối.
> 2. Cả 3 container đều gọi Redis trong health check nên đồng loạt trả 503.
> 3. Orchestrator coi liveness fail là process hỏng → restart **cả 3** container
>    cùng lúc (liveness fail nghĩa là "giết đi khởi động lại", không phải "tạm
>    đừng gửi traffic").
> 4. Container khởi động lại vẫn không nối được Redis → health vẫn 503 → lại bị
>    restart, vòng lặp crash liên tục. Trong suốt thời gian đó không còn instance
>    nào phục vụ được, kể cả những request không cần Redis.
> 5. Sau 30 giây Redis sống lại, nhưng các container đang giữa chừng khởi động
>    hoặc bị orchestrator hoãn restart (backoff) → downtime kéo dài hơn 30 giây
>    rất nhiều.
>
> Tách ra thì Redis chết chỉ làm `/ready` trả 503 → load balancer tạm ngừng gửi
> request, container không bị restart; Redis quay lại là `/ready` 200 và traffic
> chảy lại ngay. Mình thấy đúng điều này trên Railway: lúc Redis crash, `/health`
> của agent vẫn 200 còn `/ready` trả 503 `{"redis": false}`.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Mình chạy `docker compose up -d --scale agent=3` và gọi `/ask` 6 lần với cùng
> `X-User-Id`, lần lượt vào cổng 8000 → 8001 → 8002 (mỗi cổng một container).
> `history_length` thật: **0, 2, 4, 6, 8, 10** — tăng đều 2 mỗi lượt (một message
> user + một message assistant) dù mỗi request rơi vào container khác, vì cả 3
> cùng đọc/ghi `history:<user_id>` trong một Redis.
>
> Nếu lưu trong dict Python, mỗi container có dict riêng trong RAM của nó. Cùng
> kịch bản đó sẽ ra **0, 0, 0, 2, 2, 2** — mỗi container chỉ thấy các lượt rơi
> vào chính nó, nên con số nhảy lung tung tùy request vào container nào (với load
> balancer ngẫu nhiên thì càng khó đoán). Container bị restart thì lịch sử về 0.
> Với người dùng, agent "mất trí nhớ" một cách ngẫu nhiên.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Lỗi:** sau khi deploy, `railway logs` lặp lại liên tục:
>
> ```
> Mounting volume on: /var/lib/containers/railwayapp/bind-mounts/.../vol_lbq8e2w64bwv689z
> /bin/sh: 1: exec: docker-entrypoint.sh: not found
> ```
>
> và `/ready` của agent trả `503 {"status":"not ready","redis":false}`.
>
> **Tìm nguyên nhân:** dòng `Mounting volume` cho thấy đây là log của service
> **Redis** (agent không có volume), không phải của agent — thư mục đang link với
> service Redis nên `railway logs`/`railway domain` đều trỏ vào Redis. Xem
> `railway deployment list --service Redis` thấy bản deploy mới nhất không có
> `image: redis:8.2` như các bản trước mà được build từ source upload: mình đã
> chạy `railway up` khi đang link Redis, nên code của lab bị deploy đè lên service
> Redis. Start command của Redis (`exec docker-entrypoint.sh redis-server ...`)
> chạy trong image Python của mình nên không tìm thấy `docker-entrypoint.sh`.
>
> **Sửa:** `railway redeploy --service Redis --from-source -y` để deploy lại Redis
> từ image `redis:8.2` (volume vẫn giữ), tạo service riêng `agent` rồi
> `railway up --service agent` và `railway domain --service agent`. Sau đó
> `/ready` trả `200 {"status":"ready","redis":true}`. Bài học: luôn chạy
> `railway status` xem đang link service nào trước khi `railway up`.
