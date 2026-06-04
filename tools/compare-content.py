import urllib.request, re, difflib
pages = [("","home"),("o-nas-chovatelska-stanice/","o-nas"),("kontakt/","kontakt"),
         ("vrhy/","vrhy"),("nasi-psi/","nasi-psi"),("nase-feny/","nase-feny"),
         ("vzpominame/","vzpominame"),("nase-uspechy/","nase-uspechy"),("odchovy/","odchovy"),
         ("stenata-nabidka-stenat/","stenata"),("aktuality/","aktuality"),("galerie/","galerie")]
def fetch(port,path):
    try:
        return urllib.request.urlopen(f"http://127.0.0.1:{port}/{path}",timeout=15).read().decode('utf-8','ignore')
    except Exception as e: return f"ERR:{e}"
def text(h):
    h=re.sub(r'<(script|style)[^>]*>.*?</\1>','',h,flags=re.S|re.I)
    h=re.sub(r'<[^>]+>',' ',h); return re.sub(r'\s+',' ',h).strip()
def structs(h): return len(re.findall(r'<section|<h1|<h2|<h3',h)), len(re.findall(r'<img',h))
print(f"  {'stránka':<13} {'text 5002/5004':<16} {'sekce':<8} {'img':<8} shoda")
for path,name in pages:
    a=fetch(5002,path); b=fetch(5004,path)
    ta,tb=text(a),text(b)
    sa,ia=structs(a); sb,ib=structs(b)
    r=difflib.SequenceMatcher(None,ta,tb).ratio()*100
    flag = "" if r>=97 else "  <-- ROZDÍL"
    print(f"  {name:<13} {len(ta):>6}/{len(tb):<8} {f'{sa}/{sb}':<8} {f'{ia}/{ib}':<8} {r:.1f}%{flag}")
