FROM python:3.11

# Çalışma klasörü oluştur
WORKDIR /code

# Gerekli dosyaları kopyala
COPY ./requirements.txt /code/requirements.txt

# Kütüphaneleri kur
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# Tüm kodları sunucuya kopyala
COPY . .

# Hugging Face portunu dışa aç
EXPOSE 7860

# Sunucuyu başlat
CMD ["python", "main.py"]
