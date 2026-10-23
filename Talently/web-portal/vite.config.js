import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => {
  // SAP_API_TARGET and SAP_COOKIE come from .env (not exposed to the browser bundle)
  const env = loadEnv(mode, process.cwd(), '')

  return {
    plugins: [react()],
    server: {
      proxy: {
        '/sap-api': {
          target: env.SAP_API_TARGET,
          changeOrigin: true,
          secure: false,
          rewrite: (path) => path.replace(/^\/sap-api/, ''),
          configure: (proxy, options) => {
            proxy.on('proxyReq', (proxyReq, req, res) => {
              if (env.SAP_COOKIE) {
                proxyReq.setHeader('Cookie', env.SAP_COOKIE);
              }
            });
          }
        }
      }
    }
  }
})
