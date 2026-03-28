# ✨ AI Face Recognition Attendance System

A modern, intelligent, and secure **AI-powered Attendance Management System** built with Flutter, designed to eliminate manual tracking and prevent fraudulent entries.

---

## 🚀 Overview

This application combines **Face Recognition 🤳** and **Real-time GPS Verification 📍** to ensure every attendance record is authentic and location-validated.

Using **on-device Machine Learning (ML) 🧠**, the system accurately identifies users through facial embeddings, making proxy attendance virtually impossible.

---

## 🧠 How AI Works in This App

- 📸 Capture face using camera  
- 🧍 Detect face using ML Kit  
- 🔢 Convert face into **embedding (192-dimension vector)** using TFLite  
- 🔍 Compare embeddings using **cosine similarity**  
- ✅ Match → Attendance marked  
- ❌ No match → Rejected  

👉 Ensures fast, accurate, and secure identity verification.

---

## 🚀 Key Features

### 🤳 Smart Face Attendance
- One-tap attendance using face recognition  
- Real-time identity verification using AI  
- Prevents proxy and fake attendance  

---

### 📍 Location-Based Validation
- GPS-based attendance verification  
- Ensures user is within allowed location range  
- Prevents remote check-ins  

---

### ⏱️ Smart Work Hour Tracking
- First check-in → start time  
- Last check-out → end time  
- Automatic total hours calculation  

---

### 📊 Intelligent Status System
- ✅ Present (≥ 8 hours)  
- 🌓 Half Day (≥ 4 hours)  
- 🏠 Work From Home (WFH) (< 4 hours)  
- ⏰ Late (check-in after 10:00 AM)  

---

### 👨‍💻 Employee Features
- ⚡ Real-time attendance status  
- 📅 Attendance history & insights  
- 👤 Profile with monthly analytics  
- 📊 Performance tracking  

---

### 🧑‍💼 Admin Features
- 📊 Dashboard with employee status  
- 🟢🟡🔴 Attendance summaries (Present / WFH / Absent / Late)  
- 🎯 Filters for easy tracking  
- ⚙️ Manage and control attendance records  

---

### 📅 History & Analytics
- View past attendance records  
- Monthly performance insights  
- Attendance percentage tracking  

---

### 🔔 Smart Notifications
- ⏰ Check-in reminder (morning)  
- 🕕 Check-out reminder (evening)  

---

### 📶 Offline Support
- Store attendance locally  
- Auto sync when internet is available  

---

### 🎨 UI / UX
- Smooth animations  
- Clean and modern design  
- Responsive and user-friendly interface  
- Dark mode support  

---

## 🔐 Security & Reliability

- 🧠 AI-based face verification  
- 📍 Location-based validation  
- 🔒 Role-based access control  
- 📶 Offline-first architecture  
- 🔁 Face re-registration protection  
- 🔐 Secure authentication (Supabase)  

---

## 🏗️ Tech Stack

- **Flutter** — UI Framework  
- **Riverpod** — State Management  
- **GoRouter** — Navigation  
- **Supabase** — Auth + Database + Storage  
- **ML Kit** — Face Detection  
- **TensorFlow Lite** — Face Embeddings  
- **Geolocator** — Location Tracking  
- **Hive / SharedPreferences** — Local Storage  

---

## 💡 Why This App?

- 🚫 Eliminates proxy attendance  
- ⚡ Fast and real-time processing  
- 🔐 Highly secure system  
- 📊 Data-driven insights  
- 🌍 Scalable for real-world use  

---

## 🏁 Conclusion

This project delivers a **secure, scalable, and enterprise-ready attendance solution** powered by AI and modern mobile technologies, ensuring accuracy, transparency, and efficiency in workforce management.

---
