import React,{createContext,useContext,useEffect,useState} from "react";
const C=createContext(null);
export function PreferencesProvider({children}){
 const [theme,setTheme]=useState(()=>localStorage.theme||"system");
 const [lang,setLang]=useState(()=>localStorage.lang||(navigator.language.startsWith("hi")?"hi":"en"));
 useEffect(()=>{localStorage.theme=theme;const resolved=theme==="system"?(matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light"):theme;document.documentElement.dataset.theme=resolved;},[theme]);
 useEffect(()=>{localStorage.lang=lang;document.documentElement.lang=lang;},[lang]);
 return <C.Provider value={{theme,setTheme,lang,setLang}}>{children}</C.Provider>;
}export const usePreferences=()=>useContext(C);
