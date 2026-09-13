import json
import gzip
import re
import random

# --- KATEGORİ SÖZLÜĞÜ ---
CATEGORIES = {
    "tisort": ["t-shirt", "tshirt", "tee", "polo", "tank top"],
    "sweatshirt": ["sweater", "sweatshirt", "hoodie", "pullover", "knit", "fleece"],
    "gomlek": ["shirt", "button down", "blouse", "flannel", "linen"],
    "ceket_mont": ["jacket", "coat", "blazer", "outerwear", "parka", "vest", "cardigan"],
    "pantolon": ["pants", "jeans", "trouser", "leggings", "sweatpants", "chino", "jogger"],
    "sort_etek": ["shorts", "skirt"],
    "elbise": ["dress", "gown"],
    "ayakkabi": ["shoes", "sneaker", "boots", "sandals", "heels", "loafers"]
}

# --- STYLE TAGS SÖZLÜĞÜ ---
TAG_DICTIONARY = {
    # Cinsiyet ve Yaş
    "kadın": ["women", "womens", "woman", "girl", "girls", "ladies", "female"],
    "erkek": ["men", "mens", "man", "boy", "boys", "guy", "male"],
    "unisex": ["unisex", "neutral"],

    # Mevsim ve Hava Durumu
    "kışlık": ["winter", "warm", "fleece", "plush", "snow", "cold", "thermal", "insulated", "heavyweight"],
    "yazlık": ["summer", "beach", "swim", "lightweight", "breathable", "cool", "sun", "tropical"],
    "mevsimlik": ["spring", "fall", "autumn", "transitional", "all-season"],

    # Giyim Tarzı (Grok için en kritik kısım)
    "spor": ["sport", "athletic", "running", "gym", "workout", "yoga", "active", "performance", "training"],
    "klasik": ["classic", "formal", "business", "office", "dressy", "elegant", "professional"],
    "casual": ["casual", "daily", "everyday", "relaxed", "leisure"],
    "vintage": ["vintage", "retro", "90s", "80s", "old school"],
    "sokak-stili": ["streetwear", "urban", "hip hop", "skate", "graphic"],
    "slim-fit": ["slim", "skinny", "tight", "fitted", "bodycon"],
    "oversize": ["oversize", "oversized", "loose", "baggy", "wide leg", "relaxed fit"],

    # Renkler (Genişletilmiş)
    "siyah": ["black", "dark", "charcoal", "ebony"],
    "beyaz": ["white", "cream", "ivory", "off-white", "snow"],
    "mavi": ["blue", "navy", "denim", "azure", "sky blue", "indigo"],
    "kırmızı": ["red", "burgundy", "wine", "maroon", "crimson"],
    "yeşil": ["green", "olive", "khaki", "emerald", "mint"],
    "sarı": ["yellow", "gold", "mustard"],
    "pembe": ["pink", "rose", "fuchsia", "coral"],
    "gri": ["gray", "grey", "silver", "heather"],
    "kahverengi": ["brown", "tan", "beige", "camel", "chocolate"],
    "çok-renkli": ["multi", "colorblock", "patterned", "floral", "striped", "print"],

    # Materyal ve Doku
    "pamuklu": ["cotton", "combed"],
    "deri": ["leather", "faux leather", "pu leather", "vegan leather"],
    "kot": ["denim", "jean"],
    "yünlü": ["wool", "cashmere", "merino"],
    "ipek": ["silk", "satin"],
    "keten": ["linen"],
    "kadife": ["velvet", "corduroy"],
    "su-geçirmez": ["waterproof", "water-resistant", "rain"],

    # Detaylar
    "fermuarlı": ["zip", "zipper", "full-zip"],
    "düğmeli": ["button", "button-down"],
    "kapüşonlu": ["hoodie", "hooded"],
    "v-yaka": ["v-neck"],
    "bisiklet-yaka": ["crew neck", "round neck"],
    "kısa-kollu": ["short sleeve", "sleeveless"],
    "uzun-kollu": ["long sleeve"]
}

def generate_style_tags(title, category):
    title_lower = title.lower()
    tags = [category]
    for tr_tag, en_keywords in TAG_DICTIONARY.items():
        for keyword in en_keywords:
            if re.search(r'\b' + re.escape(keyword) + r'\b', title_lower):
                tags.append(tr_tag)
                break 
    return list(set(tags))

def process_to_catalog(input_file, output_file):
    katalog = []
    print(f">>> {input_file} taranıyor, Katalog oluşturuluyor...")

    try:
        with gzip.open(input_file, 'rt', encoding='utf-8') as f:
            count = 0
            for line in f:
                count += 1
                if count % 10000 == 0: # Dosya küçükse daha sık log görelim
                    print(f"[{count}] satır işlendi...")
                    
                try:
                    # Bazı Amazon dosyaları tek satırda tam JSON değil, 
                    # Python sözlüğü gibi (single quote) olabiliyor, ast.literal_eval gerekebilir ama 
                    # önce standart json deneyelim.
                    item = json.loads(line.strip())
                    
                    if 'asin' not in item or 'title' not in item:
                        continue
                    
                    # RESİM KONTROLÜ (Farklı anahtar isimlerini deniyoruz)
                    img_url = None
                    if item.get('imageURLHighRes') and len(item['imageURLHighRes']) > 0:
                        img_url = item['imageURLHighRes'][0]
                    elif item.get('image') and len(item['image']) > 0:
                        img_url = item['image'][0]
                    elif item.get('imUrl'): # Eski sürümlerde bu kullanılır
                        img_url = item['imUrl']
                        
                    if not img_url:
                        continue # Resim yoksa atla
                    
                    title = item['title']
                    category = "unknown"
                    
                    for cat, keywords in CATEGORIES.items():
                        if any(re.search(r'\b' + re.escape(k) + r'\b', title.lower()) for k in keywords):
                            category = cat
                            break
                    
                    if category != "unknown":
                        random_price = random.randrange(500, 2100, 100)
                        
                        catalog_item = {
                            "id": f"AMZ-{item['asin']}",
                            "name": title[:70] + "..." if len(title) > 70 else title,
                            "category": category,
                            "description": f"{item.get('brand', 'Global')} markalı katalog ürünü.",
                            "imageUrl": img_url,
                            "price": random_price,
                            "priceText": f"{random_price} TL",
                            "size": "Standart",
                            "styleTags": generate_style_tags(title, category),
                            "type": "amazon"
                        }
                        katalog.append(catalog_item)
                except Exception:
                    continue
    except FileNotFoundError:
        print(f"HATA: {input_file} dosyası bulunamadı!")
        return

    print(f">>> İşlem bitti. Toplam {len(katalog)} kaliteli ürün kataloga eklendi.")
    
    with open(output_file, 'w', encoding='utf-8') as out:
        json.dump(katalog, out, indent=4, ensure_ascii=False)

if __name__ == "__main__":
    process_to_catalog("meta_AMAZON_FASHION.json.gz", "amazon_katalog.json")