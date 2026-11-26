import {usePreferences} from "../context/PreferencesContext";
import en from "../locales/en.json";import hi from "../locales/hi.json";
export default function useI18n(){const {lang}=usePreferences();const dict=lang==="hi"?hi:en;return {t:(key,p)=>{let s=dict[key]||key;if(p)Object.entries(p).forEach(([k,v])=>s=s.replaceAll(`{${k}}`,v));return s;},lang};}
