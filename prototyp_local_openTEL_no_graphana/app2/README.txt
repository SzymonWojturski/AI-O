werjsa apki gdzie pobieramy openlit z githuba za pomocą:

git clone https://github.com/openlit/openlit.git
cd openlit

uruchamiamy używając:

sudo docker compose up -d

a na końcu żeby zobaczyć ui openlit u siebie na kompie:

ssh -i sciezka/do/klucza.pem -L 3000:localhost:3000 ubuntu@<PUBLIC_IP_EC2>
