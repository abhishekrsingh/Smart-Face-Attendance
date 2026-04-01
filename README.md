# 🤳 FaceTrack — AI Face Recognition Attendance System

> A smart, secure, and AI-powered attendance solution built with Flutter.
> No proxies. No manual entries. Just your face. ✅

---

## 🚀 Overview

FaceTrack uses **on-device Face Recognition** + **Real-time GPS** to make every attendance record authentic and tamper-proof. Employees check in with a single tap — the AI does the rest.

---

## 🧠 How Face Recognition Works

```
📸 Camera Capture
    ↓
🧍 Face Detection — ML Kit
    ↓
🔢 192-Dimension Embedding — TFLite (ArcFace)
    ↓
🔍 Cosine Similarity Comparison
    ↓
✅ Match → Attendance Marked   ❌ No Match → Rejected
```

---

## ✨ Features

### 🤳 Face Attendance

- One-tap check-in using real-time face recognition
- On-device AI — no server round-trip for matching
- Prevents proxy and fake attendance completely
- **Re-check-in** support if accidentally checked out

### 📍 Location Validation

- GPS coordinates captured on every check-in
- Location stored and verifiable per record

### ⏱️ Work Hour Tracking

- Auto start/stop timer on check-in and check-out
- Total hours calculated and stored automatically

### 📊 Smart Status System

| Status     | Condition                |
| ---------- | ------------------------ |
| ✅ Present | Checked in               |
| 🏠 WFH     | Work From Home           |
| ❌ Absent  | No check-in              |
| ⏰ Late    | Check-in after threshold |

### 📅 Attendance History

- Full monthly view with date navigation
- Per-day detail: check-in time, check-out time, hours, late badge
- Monthly summary — Present / WFH / Absent / Late counts

### ✅ Daily Task Management

- Add, edit, delete tasks per attendance day
- Three statuses: **Pending → In Progress → Done**
- Tap status chip to cycle — instant update
- Tasks are linked to the day's attendance record

### 👤 Profile & Analytics

- View and edit name, department, avatar
- Monthly stats grid — hours, attendance breakdown
- Change password with current-password verification

---

## 🏗️ Tech Stack

| Layer           | Tech                           |
| --------------- | ------------------------------ |
| UI              | Flutter                        |
| State           | Riverpod                       |
| Navigation      | GoRouter                       |
| Backend         | Supabase (Auth + DB + Storage) |
| Face Detection  | ML Kit                         |
| Face Embeddings | TensorFlow Lite                |
| Location        | Geolocator                     |
| Local DB        | Isar                           |
| Image           | image_picker                   |

---

## 🔐 Security

- 🧠 On-device face matching — embeddings never sent to server
- 📍 GPS coordinates recorded per check-in
- 🔒 Supabase RLS — users access only their own data
- 👤 Role-based access: `employee` / `admin`

---

## 💡 Why FaceTrack?

| Problem            | How We Solve It                                       |
| ------------------ | ----------------------------------------------------- |
| Proxy attendance   | Face verified on-device — no spoofing                 |
| Manual errors      | Fully automated check-in / out                        |
| No task visibility | Per-day task tracker built-in                         |
| Slow data loads    | Isar cache → instant UI, Supabase syncs in background |
