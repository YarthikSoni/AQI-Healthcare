export const API=import.meta.env.VITE_API_URL||"http://localhost:8000/api/v1";
export async function api(path,options={}){const r=await fetch(API+path,options);const d=await r.json().catch(()=>({detail:r.statusText}));if(!r.ok)throw new Error(d.detail||"Request failed");return d;}
