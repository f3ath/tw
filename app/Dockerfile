FROM nginx:alpine

COPY app/nginx.conf /etc/nginx/conf.d/default.conf
COPY app/build/web/ /usr/share/nginx/html/

EXPOSE 8080
