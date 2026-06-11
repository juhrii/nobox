# TODO - Fix Filter Conversation (anti-dummy)

## Step 1 (planned)
- Audit filter inputs/outputs (Name vs Id) untuk dropdown: Contact, Link, Group, Campaign, Deal, Funnel, Tags, HumanAgent.

## Step 2 (planned)
- Ubah filter logic dari lokal string matching menjadi server-side EqualityFilter berbasis Id.

## Step 3
- Update ChatProvider: ganti filter fields agar menyimpan Id (ctId, FnId, DealId, CampaignId, GrpId, AgentId, LinkId).

## Step 4
- Update ChatService.getConversations(): tambahkan EqualityFilter untuk field-field Id.

## Step 5
- Update UI _showFilterDialog(): simpan value dropdown dalam bentuk Id (bukan Name) untuk semua filter yang relevan.

## Step 6
- Tambahkan fallback lokal (hanya jika server tidak menyediakan field yang dibutuhkan).

## Step 7
- Testing manual: pilih filter satu per satu dan verifikasi hasil list.

