require 'httparty'
require 'nokogiri'
require 'csv'

# ============================================================
# TÍA
# Electrodomésticos línea blanca - Precio menor a $400
# ============================================================

url = "https://www.tia.com.ec/home_linea_blanca"

response = HTTParty.get(url)
doc = Nokogiri::HTML(response.body)

resultados = []

doc.css("li.product-item").each do |producto|

  titulo = producto.css(".product-item-link").text.strip

  precio_texto = producto.css(".price").first&.text

  if precio_texto
    precio = precio_texto.gsub("$", "").gsub(".", "").gsub(",", ".").strip.to_f

    if precio < 400
      puts "#{titulo} - $#{precio}"

      resultados << [
        "Tía",
        "Electrodomésticos línea blanca",
        titulo,
        precio,
        "USD"
      ]
    end
  end
end

# ============================================================
# CASA DEL LIBRO
# Novedades / libros más vendidos - Precio menor a 40 €
# ============================================================

url = "https://www.casadellibro.com/libros"

response = HTTParty.get(url)
doc = Nokogiri::HTML(response.body)

doc.css("article").each do |libro|

  titulo = libro.css("h2, h3, .title").first&.text&.strip
  precio_texto = libro.css(".price").first&.text

  if titulo && precio_texto
    precio = precio_texto.gsub("€", "").gsub(",", ".").strip.to_f

    if precio > 0 && precio < 40
      puts "#{titulo} - #{precio} €"

      resultados << [
        "Casa del Libro",
        "Novedades / libros más vendidos",
        titulo,
        precio,
        "EUR"
      ]
    end
  end
end


# ============================================================
# EL BOSQUE
# Comedores - Precio mayor a $100
# ============================================================

url = "https://www.bosque.com.ec/comedores/mesas-de-comedor"

response = HTTParty.get(url)
doc = Nokogiri::HTML(response.body)

doc.css("article").each do |producto|

  titulo = producto.css("[class*='productName'], [class*='ProductName']").first&.text&.strip

  precio_texto = producto.css("[class*='sellingPrice'], [class*='SellingPrice']").first&.text

  if titulo && precio_texto
    precio = precio_texto.gsub("$", "").gsub(".", "").gsub(",", ".").strip.to_f

    if precio > 100
      puts "#{titulo} - $#{precio}"

      resultados << [
        "El Bosque",
        "Comedores",
        titulo,
        precio,
        "USD"
      ]
    end
  end
end


# ============================================================
# GENERAR CSV
# ============================================================

CSV.open("productos_scraping.csv", "w", write_headers: true,
         headers: ["Sitio", "Categoría", "Producto", "Precio", "Moneda"]) do |csv|

  resultados.each do |producto|
    csv << producto
  end

end

puts ""
puts "=========================================="
puts "Scraping terminado."
puts "Archivo generado: productos_scraping.csv"
puts "Productos encontrados: #{resultados.length}"
puts "=========================================="
```
