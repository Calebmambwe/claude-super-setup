import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3010,
    host: "0.0.0.0",
    proxy: {
      "/api": "http://localhost:3011",
      "/ws": {
        target: "ws://localhost:3011",
        ws: true,
      },
    },
  },
});
