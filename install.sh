#!/bin/bash

# بررسی دسترسی روت
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[31m[ERROR]\033[0m Please run this script as \033[1mroot\033[0m."
    exit 1
fi

# نمایش لوگو
function show_logo() {
    clear
    echo -e "\033[1;34m"
    echo "========================================"
    echo "           MIRZA INSTALL SCRIPT         "
    echo "========================================"
    echo -e "\033[0m"
    echo ""
}

# نمایش منو
function show_menu() {
    echo -e "\033[1;36m1)\033[0m Install Mirza Bot"
    echo -e "\033[1;36m2)\033[0m Update Mirza Bot"
    echo -e "\033[1;36m3)\033[0m Remove Mirza Bot"
    echo -e "\033[1;36m4)\033[0m Exit"
    echo ""
    read -p "Select an option [1-4]: " option
    case $option in
        1) install_bot ;;
        2) update_bot ;;
        3) remove_bot ;;
        4)
            echo -e "\033[32mExiting...\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[31mInvalid option. Please try again.\033[0m"
            show_menu
            ;;
    esac
}
   # تابع نصب
function install_bot() {
    echo -e "\e[32mInstalling Mirza Bot ... \033[0m\n"

    # افزودن PPA برای PHP
    function add_php_ppa() {
        sudo add-apt-repository -y ppa:ondrej/php || \
        (echo "Failed to add PPA. Retrying with locale override..." && \
        sudo LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php) || \
        (echo "Failed to add PPA even with locale override. Exiting..." && exit 1)
    }

    # به‌روزرسانی و ارتقای سیستم
    sudo apt update && sudo apt upgrade -y || { echo "Failed to update system. Exiting..."; exit 1; }
    echo -e "\e[92mSystem updated successfully.\033[0m\n"

    # نصب PHP و ماژول‌ها
    local php_packages=("php8.2" "php8.2-fpm" "php8.2-mysql")
    for pkg in "${php_packages[@]}"; do
        sudo apt install -y "$pkg" || { echo "Failed to install $pkg. Exiting..."; exit 1; }
    done

    # نصب بسته‌های اضافی
    local additional_packages=(
        "lamp-server^" "libapache2-mod-php" "mysql-server" "apache2" 
        "php-mbstring" "php-zip" "php-gd" "php-json" "php-curl" 
        "php-soap" "git" "wget" "unzip" "curl" "php-ssh2" "ufw"
    )

    for pkg in "${additional_packages[@]}"; do
        if ! dpkg -s "$pkg" &> /dev/null; then
            sudo apt install -y "$pkg" || { echo "Error installing $pkg. Exiting..."; exit 1; }
        else
            echo "$pkg is already installed."
        fi
    done

    echo -e "\n\e[92mRequired packages installed successfully.\033[0m\n"

    # تنظیم phpMyAdmin
    echo 'phpmyadmin phpmyadmin/dbconfig-install boolean true' | sudo debconf-set-selections
    echo 'phpmyadmin phpmyadmin/app-password-confirm password mirzahipass' | sudo debconf-set-selections
    echo 'phpmyadmin phpmyadmin/mysql/admin-pass password mirzahipass' | sudo debconf-set-selections
    echo 'phpmyadmin phpmyadmin/mysql/app-pass password mirzahipass' | sudo debconf-set-selections
    echo 'phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2' | sudo debconf-set-selections

    sudo apt-get install -y phpmyadmin || { echo "Failed to install phpMyAdmin. Exiting..."; exit 1; }

    sudo ln -sf /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
    sudo a2enconf phpmyadmin.conf
    sudo systemctl restart apache2 || { echo "Failed to restart Apache2. Exiting..."; exit 1; }

    # فعال‌سازی UFW و باز کردن پورت‌ها
    sudo ufw allow 'Apache' || { echo "Failed to configure UFW. Exiting..."; exit 1; }

    # کلون کردن فایل‌های ربات
    if ! git clone https://github.com/mahdiMGF2/botmirzapanel.git /var/www/html/mirzabotconfig; then
        echo "Failed to clone bot repository. Exiting..."
        exit 1
    fi

    sudo chown -R www-data:www-data /var/www/html/mirzabotconfig/
    sudo chmod -R 755 /var/www/html/mirzabotconfig/

    echo -e "\n\033[33mMirza Bot configuration files installed successfully.\033[0m"

    # تنظیمات پایگاه داده
    configure_database

    # تنظیم SSL
    configure_ssl

    echo -e "\n\e[32mMirza Bot has been installed successfully!\033[0m\n"
}

function configure_database() {
    echo -e "\e[32mConfiguring database...\033[0m"

    local root_pass="mirzahipass"
    local dbname="mirzabot"
    local dbuser="mirzabot_user"
    local dbpass=$(openssl rand -base64 10 | tr -dc 'a-zA-Z0-9' | cut -c1-8)

    sudo mysql -u root -p"${root_pass}" -e "
        CREATE DATABASE IF NOT EXISTS ${dbname};
        CREATE USER IF NOT EXISTS '${dbuser}'@'localhost' IDENTIFIED BY '${dbpass}';
        GRANT ALL PRIVILEGES ON ${dbname}.* TO '${dbuser}'@'localhost';
        FLUSH PRIVILEGES;" || { echo "Database configuration failed. Exiting..."; exit 1; }

    echo -e "\n\e[92mDatabase configured successfully.\033[0m"
}

function configure_ssl() {
    echo -e "\e[32mConfiguring SSL...\033[0m"

    read -p "Enter the domain name for SSL (or leave blank to skip): " domainname
    if [[ -n "$domainname" ]]; then
        sudo apt install -y certbot python3-certbot-apache || { echo "Failed to install Certbot. Exiting..."; exit 1; }
        sudo certbot --apache --non-interactive --agree-tos --redirect -d "$domainname" || { echo "SSL configuration failed. Exiting..."; exit 1; }

        echo -e "\n\e[92mSSL configured successfully for $domainname.\033[0m"
    else
        echo "Skipping SSL configuration."
    fi
}
# تابع آپدیت
function update_bot() {
    echo "Updating Mirza Bot..."
    sudo apt update && sudo apt upgrade -y
    echo -e "\e[92mThe server was successfully updated ...\033[0m\n"
    sudo apt-get install -y git
    sudo apt install curl -y
    echo -e "\n\e[92mUpdating Bot...\033[0m\n"
    sleep 2
    mv /var/www/html/mirzabotconfig/config.php /root/
    rm -r /var/www/html/mirzabotconfig
    git clone https://github.com/mahdiMGF2/botmirzapanel.git /var/www/html/mirzabotconfig
    sudo chown -R www-data:www-data /var/www/html/mirzabotconfig/
    sudo chmod -R 755 /var/www/html/mirzabotconfig/
    mv /root/config.php /var/www/html/mirzabotconfig/
    urlbot=$(cat /var/www/html/mirzabotconfig/config.php | grep '$domainhosts' | cut -d'"' -d"'" -f2)
    curl "https://$urlbot/table.php"
    clear
    echo -e "\n\e[92mMirza robot has been successfully updated!"
}

# تابع حذف
function remove_bot() {
    echo "Removing Mirza Bot..."
    rm -r /var/www/html/mirzabotconfig
    echo -e "\e[91mMirza Bot has been removed.\033[0m"
}

# اجرای منو
show_logo
show_menu
