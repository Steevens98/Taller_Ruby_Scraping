require 'httparty'
require 'nokogiri'
require 'csv'
require 'json'

resultados = []

# ============================================================
# TÍA
# Electrodomésticos línea blanca - Precio menor a $400
# ============================================================
url = "https://www.tia.com.ec/home_linea_blanca"
response = HTTParty.get(url)
doc = Nokogiri::HTML(response.body)

doc.css("li.product-item").each do |producto|
  titulo = producto.css(".product-item-link").text.strip
  precio_texto = producto.css(".price").first&.text

  if precio_texto
    precio = precio_texto
      .gsub("$", "")
      .gsub(".", "")
      .gsub(",", ".")
      .strip
      .to_f

    if precio < 400
      puts "Tía: #{titulo} - $#{precio}"
      resultados << ["Tía","Electrodomésticos línea blanca",titulo,precio,"USD"]
    end
  end
end

# ============================================================
# CASA DEL LIBRO
# Libros más vendidos - Precio menor a 40 €
# ============================================================
BASE_URL_CASA = "https://www.casadellibro.com"
API_PRECIO_CASA ="https://p.casadellibro.com/cdlweb/api/precio/preciosbuscador"

def obtener_precio_casa(id_producto)
  response = HTTParty.get(
    API_PRECIO_CASA,
    query: {
      paiscache: 63,
      idproductos: id_producto,
      cop: "63-46-1-63-0-0-1-2-2--0-0-0-0-0-0-0.0-0"
    },
    headers: {
      "User-Agent" => "Mozilla/5.0",
      "Accept" => "application/json"
    }
  )

  return nil unless response.success?

  begin
    datos = JSON.parse(response.body)
    producto = datos.first
    return nil if producto.nil?

    precio = producto["precios"].find { |p| p["type"].to_i == 1 }
    return nil if precio.nil?

    precio["realAmount"].to_f

  rescue
    nil
  end
end

response = HTTParty.get(
  "#{BASE_URL_CASA}/libros-mas-vendidos",
  headers: {
    "User-Agent" => "Mozilla/5.0",
    "Accept" => "text/html"
  }
)

if response.success?

  doc = Nokogiri::HTML(response.body)
  libros = doc.css(".product-card")

  libros.each do |libro|
    titulo = libro.at_css("a.product-title")&.text&.strip
    next if titulo.nil?

    href = libro.at_css("a.image")&.[]("href").to_s
    next unless href =~ %r{/(\d+)$}

    id_producto = $1
    precio = obtener_precio_casa(id_producto)

    next if precio.nil?
    next unless precio < 40

    puts "Casa del Libro: #{titulo} - €#{precio}"

    resultados << ["Casa del Libro","Libros más vendidos",titulo,precio,"EUR"]
  end

else
  puts "Error al acceder a Casa del Libro: HTTP #{response.code}"
end

# ============================================================
# EL BOSQUE
# Comedores - Precio mayor a $100
# ============================================================
BASE_URL = "https://www.bosque.com.ec"
pagina = 1
total_productos_bosque = 0
total_filtrados_bosque = 0

loop do
  desde = (pagina - 1) * 20
  hasta = desde + 19

  api_url = "#{BASE_URL}/api/catalog_system/pub/products/search/" \
            "?fq=C:/1/&_from=#{desde}&_to=#{hasta}"

  response = HTTParty.get(api_url,headers: {"User-Agent" => "Mozilla/5.0","Accept" => "application/json"})

  unless response.success?
    puts "Error en página #{pagina}: HTTP #{response.code}"
    break
  end

  begin

    productos = JSON.parse(response.body)

  rescue JSON::ParserError
    puts "No se pudo interpretar la respuesta de El Bosque."
    break
  end

  break if productos.empty?

  total_productos_bosque += productos.length

  productos.each do |producto|
    nombre = producto["productName"]
    next if nombre.nil?
    categorias = producto["categories"] || []

    pertenece_comedores = categorias.any? do |categoria|
      categoria.downcase.include?("comedores")
    end

    next unless pertenece_comedores

    items = producto["items"]
    next if items.nil? || items.empty?
    precio = nil

    items.each do |item|
      precio_item = item.dig("sellers",0,"commertialOffer","Price")

      unless precio_item.nil?
        precio = precio_item.to_f
        break
      end

    end

    next if precio.nil? || precio <= 0

    if precio > 100
      puts "El Bosque: #{nombre} - $#{precio}"
      resultados << ["El Bosque","Comedores",nombre,precio,"USD"]
      total_filtrados_bosque += 1
    end
  end
  break if productos.length < 20
  pagina += 1
end

# ============================================================
# GENERAR CSV
# ============================================================

CSV.open("productos_scraping.csv","w",write_headers: true,
  headers: ["Sitio","Categoría","Producto","Precio","Moneda"]
) do |csv|
  resultados.each do |producto|
    csv << producto
  end
end

puts ""
puts "Scraping terminado."
puts "Total de productos: #{resultados.length}"
