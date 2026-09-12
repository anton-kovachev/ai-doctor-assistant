import type { NextConfig } from "next";
import dotenv from "dotenv";

// Load local .env into process.env at build time so NEXT_PUBLIC_* vars are inlined
dotenv.config();

const nextConfig: NextConfig = {
  output: "export", // This exports static HTML/JS files
  images: {
    unoptimized: true, // Required for static export
  },
  env: {
    NEXT_PUBLIC_BACKEND_URL: process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000",
  },
};

export default nextConfig;
