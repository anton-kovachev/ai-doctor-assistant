import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export", // This exports static HTML/JS files
  images: {
    unoptimized: true, // Required for static export
  },
  env: {
    NEXT_PUBLIC_BACKEND_URL:
      process.env.NEXT_PUBLIC_BACKEND_URL || "http://localhost:8000",
  },
};

export default nextConfig;
