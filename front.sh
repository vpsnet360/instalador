#!/bin/bash
msg() {
  local colors="/etc/new-adm-color"
  if [[ ! -e $colors ]]; then
    COLOR[0]='\033[1;37m'  
    COLOR[1]='\e[31m'      
    COLOR[2]='\e[32m'     
    COLOR[3]='\e[33m'     
    COLOR[4]='\e[34m'      
    COLOR[5]='\e[35m'      
    COLOR[6]='\033[1;97m'  
    COLOR[7]='\033[1;49;95m' 
    COLOR[8]='\033[1;49;96m'
    COLOR[9]='\033[38;5;129m'
  else
    local COL=0
    for number in $(cat $colors); do
      case $number in
        1)COLOR[$COL]='\033[1;37m';;
        2)COLOR[$COL]='\e[31m';;
        3)COLOR[$COL]='\e[32m';;
        4)COLOR[$COL]='\e[33m';;
        5)COLOR[$COL]='\e[34m';;
        6)COLOR[$COL]='\e[35m';;
        7)COLOR[$COL]='\033[1;36m';;
        8)COLOR[$COL]='\033[1;49;95m';;
        9)COLOR[$COL]='\033[1;49;96m';;
      esac
      let COL++
    done
  fi

  NEGRITO='\e[1m'
  SEMCOR='\e[0m'

  case $1 in
    -ne) cor="${COLOR[1]}${NEGRITO}" && echo -ne "${cor}${2}${SEMCOR}" ;;
    -ama) cor="${COLOR[3]}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -verm) cor="${COLOR[3]}${NEGRITO}[!] ${COLOR[1]}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -verm2) cor="${COLOR[1]}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -aqua) cor="${COLOR[8]}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -azu) cor="${COLOR[6]}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -verd) cor="${COLOR[2]}${NEGRITO}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -bra) cor="${COLOR[0]}${SEMCOR}" && echo -e "${cor}${2}${SEMCOR}" ;;
    -bar)
      
      WIDTH=55
      echo -e "${COLOR[4]}$(printf '%.0s━' $(seq 1 $WIDTH))${SEMCOR}"
    ;;
    -bar1)
      
      WIDTH=55
      echo -e "${COLOR[4]}$(printf '%.0s━' $(seq 1 $WIDTH))${SEMCOR}"
    ;;
    -bar2)
      echo -e "${COLOR[4]}=====================================================${SEMCOR}"
    ;;
    -bar3)
      
      WIDTH=55
      echo -e "${COLOR[4]}$(printf '%.0s━' $(seq 1 $WIDTH))${SEMCOR}"
    ;;
    -bar4)
      
      echo -e "${COLOR[5]}•••••••••••••••••••••••••••••••••••••••••••••••••${SEMCOR}"
    ;;
    -bar5)
      
      WIDTH=55
      echo -e "${COLOR[4]}$(printf '%.0s━' $(seq 1 $WIDTH))${SEMCOR}"
    ;;
  esac
}

SCRIPT_PATH="/root/front.sh"
LINK_PATH="/bin/front"

if [ ! -f "$SCRIPT_PATH" ]; then
    exit 1
fi

if [ ! -L "$LINK_PATH" ]; then
    sudo ln -s "$SCRIPT_PATH" "$LINK_PATH"
    sudo chmod +x "$LINK_PATH"
fi

if [ ! -x "$SCRIPT_PATH" ]; then
    sudo chmod +x "$SCRIPT_PATH"
fi


install_and_configure_nginx() {
  sudo apt install nginx -y
  
  echo "user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
    # multi_accept on;
}

http {
    server {
        listen 80;
        access_log off;

        # Configurações de timeout para proxy
        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;

        location / {
            # Passa a requisição para o backend mapeado
            proxy_pass http://127.0.0.1:8080;

            # Define cabeçalhos padrão para proxy
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

    }
}" | sudo tee /etc/nginx/nginx.conf > /dev/null
  
  if sudo nginx -t > /dev/null 2>&1; then
        sudo systemctl restart nginx
        msg -verd "Nginx reiniciado con éxito."
    else
        msg -verm "Error en la configuración de Nginx. No se ha reiniciado."
    fi
}

add_user() {
    clear
    msg -bar
    msg -verd "AGREGAR NUEVO USUARIO"
    msg -bar
    if [ ! -f "/etc/nginx/user_data.txt" ]; then
        touch "/etc/nginx/user_data.txt"
    fi

    while true; do
        read -p "Introduce el nombre del usuario: " user_name
        user_name=$(echo "$user_name" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        msg -bar
        if [ -z "$user_name" ]; then
            msg -verm "El nombre del usuario no puede estar vacío"
        elif grep -q "^${user_name}:" "/etc/nginx/user_data.txt"; then
            msg -verm "Ya existe un usuario con el mismo nombre."
        else
            break
        fi
    done

    read -p "Introduce la IP para el usuario: " ip
    msg -bar

    while true; do
        read -p "Introduce los días de expiración (número): " days
        if [[ "$days" =~ ^[0-9]+$ ]]; then
            break
        else
            msg -verm "Los días deben ser un número."
        fi
    done

    local block=$(cat <<EOF
    location /${user_name} {
        proxy_pass http://${ip}:80;
    }
EOF
)
    echo "$block" | sudo sed -i "/server {/,/}/ { 
      /}/ r /dev/stdin
    }" /etc/nginx/nginx.conf


    local now=$(date +%s)
    local expiration_date=$((now + (days * 86400)))
    echo "${user_name}:${ip}:${expiration_date}" >> /etc/nginx/user_data.txt

    msg -verd "USUARIO ${user_name} añadida a nginx.conf con expiración en ${days} días."

    if sudo nginx -t > /dev/null 2>&1; then
        sudo systemctl restart nginx
        msg -verd "Nginx reiniciado con éxito."
    else
         echo ""
    fi

    msg -bar
}

show_users() {
  clear
  if [ ! -f /etc/nginx/user_data.txt ]; then
    msg -verm "NO HAY USUARIOS REGISTRADOS."
    return
  fi

  msg -verd "USUARIOS REGISTRADOS:"
  echo -e "\e[1;36m==================================================\e[0m"
  echo -e "\e[1;36m  Nombre          IP             Expiración\e[0m"
  echo -e "\e[1;36m==================================================\e[0m"

  local current_time=$(date +%s)
  local count=1
  local active_count=0
  local expired_count=0

  while IFS=: read -r user_name ip expiration_date; do
    local days_left=$(( (expiration_date - current_time) / 86400 ))
    
    if [ $days_left -ge 0 ]; then
      local status_color="\e[1;32m"
      local status="[+$days_left días]"
      ((active_count++))
    else
      local status_color="\e[1;31m"
      local status="[Expirado]"
      ((expired_count++))
    fi

    printf "%b[%s]%b%-15s %-15s %s\n\e[0m" "\e[1;36m" "$count" "$status_color" "$user_name" "$ip" "$status"
    ((count++))
  done < /etc/nginx/user_data.txt

  echo -e "\e[1;36m==================================================\e[0m"
  echo -e "Usuarios activos: [\e[1;32m${active_count}\e[0m]"
  echo -e "Usuarios expirados: [\e[1;31m${expired_count}\e[0m]"
}

remove_user() {
  clear
  msg -verd "⚠️ ADVERTENCIA: LOS USUARIOS EXPIRADOS SE RECOMIENDA ELIMINARLOS MANUALMENTE CON EL NÚMERO ⚠️"
  show_users

  while true; do
    read -p "Introduce el número del usuario que deseas eliminar: " user_number
    if [ -z "$user_number" ]; then
      msg -verd "No se seleccionó ningún usuario. Volviendo al menú principal."
      return
    fi

    if [[ "$user_number" =~ ^[0-9]+$ ]]; then
      all_users=$(grep -oP '(?<=location /)\w+(?= {)' /etc/nginx/nginx.conf | sort | uniq)
      user_count=$(echo "$all_users" | wc -l)
      if [ "$user_number" -gt 0 ] && [ "$user_number" -le "$user_count" ]; then
        user_to_remove=$(echo "$all_users" | sed -n "${user_number}p")
        sudo sed -i "/location \/${user_to_remove} {/,/}/d" /etc/nginx/nginx.conf
        sed -i "/^${user_to_remove}:/d" /etc/nginx/user_data.txt
        
        msg -verd "USUARIO ${user_to_remove} eliminado de nginx.conf."

        if sudo nginx -t > /dev/null 2>&1; then
          sudo systemctl restart nginx
          msg -verd "Nginx reiniciado con éxito."
        else
          echo ""
        fi
        
        return
      else
        msg -verm "Número de usuario no válido. Intente de nuevo."
      fi
    else
      msg -verm "Por favor, introduce un número válido."
    fi
  done
}
check_nginx_status() {
  if systemctl is-active --quiet nginx; then
    msg -verd "Nginx está activado"
  else
    msg -verm "Nginx está desactivado"
  fi
}

iniciarsocks() {
    local script_url="https://raw.githubusercontent.com/vpsnet360/instalador/refs/heads/main/so"
    local script_path="/etc/so"
    wget -q -O "$script_path" "$script_url"
    if [[ $? -ne 0 || ! -s "$script_path" ]]; then
        echo -e "\033[1;31mError: No se pudo descargar el script.\033[0m"
        return
    fi
    chmod +x "$script_path"

    "$script_path"
}


show_instructions() {
    clear
    msg -bar
    echo -e "\033[1;37m=== INSTRUCCIONES PARA CONFIGURAR Y CONECTAR ===\033[0m"
    msg -bar
    echo -e "\033[1;36mPASO 1:\033[0m INSTALAR NGINX DESDE LA OPCIÓN [1]."
    echo -e "       ⚠️ ASEGÚRATE DE QUE EL PUERTO 80 NO ESTÉ EN USO."
    msg -bar
    echo -e "\033[1;36mPASO 2:\033[0m INSTALAR PYTHON CON LA OPCIÓN [6]."
    echo -e "📌 SE CONFIGURARÁ EN EL PUERTO 8080."
    echo -e "   REDIRIGIRÁ AL PUERTO SSH O DROPBEAR ACTIVO."
    msg -bar
    echo -e "\033[1;36mPASO 3:\033[0m USA LA OPCIÓN [1] NUEVAMENTE PARA REINICIAR NGINX."
    echo -e "   🔄 ESTO APLICARÁ CORRECTAMENTE LA CONFIGURACIÓN DE PYTHON."
    msg -bar
    echo -e "\033[1;36mPASO 4:\033[0m AGREGA LOS USUARIOS CON LA OPCIÓN [2]"
    msg -bar
    echo -e "\033[1;36mPASO 5:\033[0m CONFIGURACIÓN PARA CONECTAR CON CLARO."
    echo -e "       USA EL SIGUIENTE PAYLOAD CON UN DOMINIO CLOUDFRONT:"
    echo -e "       \033[1;37mGET / HTTP/1.1[crlf]"
    echo -e "       Host: static1.claromusica.com[crlf][crlf][split]"
    echo -e "       GET /user HTTP/1.1[crlf]"
    echo -e "       Host: sub[crlf]"
    echo -e "       Connection: Upgrade[crlf]"
    echo -e "       User-Agent: [ua][crlf]"
    echo -e "       Upgrade: websocket[crlf][crlf]\033[0m"
    echo -e " 🔹 PARA CONECTAR A LA MISMA VPS CON NGINX,"
    echo -e "   ELIMINA '/USER' Y DEJA SOLO '/'."
    msg -bar
    echo -e "\033[1;36m:\033[0m PAYLOAD PARA CONECTAR CON PERSONAL."
    echo -e "       USA ESTE PAYLOAD:"
    echo -e "       \033[1;37mPUT / HTTP/1.1[crlf]"
    echo -e "       Host: [host][crlf] [crlf]"
    echo -e "       GET /user HTTP/1.1[lf]"
    echo -e "       Host: sub[lf]"
    echo -e "       Back: claro.com.py[lf]"
    echo -e "       Connection: Upgrade[lf]"
    echo -e "       Upgrade: Websocket[lf][lf]\033[0m"
    echo -e "   🔹 FUNCIONA IGUAL QUE EL PAYLOAD DE CLARO."
    
    echo -e "\033[1;36mPASO 6:\033[0m REEMPLAZAR 'sub' CON SU DOMINIO CLOUDFRONT."
    msg -bar
}

# Desinstalar nginx
uninstall_nginx() {
  sudo apt purge nginx nginx-common -y
  sudo apt autoremove -y
  sudo rm -f /etc/nginx/nginx.conf
  msg -verd "Nginx desinstalado y nginx.conf eliminado."
}
while true; do
    clear
    msg -bar
    echo -e "\E[41;1;37m                WEBSOCKET SEGURITY                 \E[0m"
    msg -verd "MENÚ NGINX (V1)"
    check_nginx_status 

    msg -bar
    echo -e "\033[0;32m [\033[0;36m01\033[0;32m]\033[0;33m >\033[0;36m INSTALAR Y REINICIAR NGINX"
    echo -e "\033[0;32m [\033[0;36m02\033[0;32m]\033[0;33m >\033[0;36m AÑADIR USUARIO"
    echo -e "\033[0;32m [\033[0;36m03\033[0;32m]\033[0;33m >\033[0;36m MOSTRAR USUARIOS REGISTRADOS"
    echo -e "\033[0;32m [\033[0;36m04\033[0;32m]\033[0;33m >\033[0;36m ELIMINAR USUARIO"
    echo -e "\033[0;32m [\033[0;36m05\033[0;32m]\033[0;33m >\033[0;31m DESINSTALAR NGINX"
    echo -e "\033[0;32m [\033[0;36m06\033[0;32m]\033[0;33m >\033[0;36m PROXY PYTHON"
    echo -e "\033[0;32m [\033[0;36m07\033[0;32m]\033[0;33m >\033[0;36m INSTRUCCIONES DE CONFIGURACIÓN"
    echo -e "\033[0;32m [\033[0;36m08\033[0;32m]\033[0;33m >\033[0;36m SALIR"
    msg -bar

    read -p "SELECCIONA UNA OPCIÓN: " choice

    case $choice in
        1) install_and_configure_nginx ;;
        2) add_user ;;
        3) show_users ;;
        4) remove_user ;;
        5) uninstall_nginx ;;
        6) iniciarsocks ;;
        7) show_instructions ;;
        8) exit 0 ;;
        *) msg -verm "OPCIÓN NO VÁLIDA. POR FAVOR, INTENTA DE NUEVO." ;;
    esac

    read -p "PRESIONA ENTER PARA CONTINUAR..."
done
