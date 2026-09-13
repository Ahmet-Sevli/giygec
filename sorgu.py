from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, firestore

# 1. Firebase Kurulumu
cred = credentials.Certificate("giygec-4738f-firebase-adminsdk-fbsvc-8e81963086.json") 
# Firestore için databaseURL belirtmene gerek yok, sadece initialize_app yeterlidir
firebase_admin.initialize_app(cred)

# Firestore istemcisini başlat
db = firestore.client()

app = Flask(__name__)

@app.route('/check-payment', methods=['GET'])
def check_payment():
    # NodeMCU'dan gelen UID'yi al (Örn: 04:52:FC:AA)
    uid = request.args.get('uid') 
    
    if not uid:
        return jsonify({"status": "error", "message": "UID eksik"}), 400

    try:
        # 2. Firestore'da Koleksiyon ve Döküman Sorgulama
        # 'products' koleksiyonundaki belge adı(ID'si) gelen UID olan belgeyi referans al
        doc_ref = db.collection('products').document(uid)
        doc = doc_ref.get()

        # 3. Belge var mı ve ödeme durumu nedir kontrol et
        if doc.exists:
            product_data = doc.to_dict()
            if product_data.get('isPaid') == True:
                return jsonify({"paid": True}), 200
            else:
                return jsonify({"paid": False}), 200
        else:
            # Ürün veritabanında hiç yoksa
            return jsonify({"paid": False, "message": "Urun bulunamadi"}), 404
            
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)