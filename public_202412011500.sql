PGDMP                       |            postgres    17.0    17.0 �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                           false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                           false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                           false            �           1262    5    postgres    DATABASE     |   CREATE DATABASE postgres WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Russian_Russia.1251';
    DROP DATABASE postgres;
                     postgres    false            �           0    0    DATABASE postgres    COMMENT     N   COMMENT ON DATABASE postgres IS 'default administrative connection database';
                        postgres    false    5012                        2615    2200    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
                     pg_database_owner    false            �           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                        pg_database_owner    false    4                       1255    16656 #   update_order_item_status_and_time()    FUNCTION     �  CREATE FUNCTION public.update_order_item_status_and_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Если статус изменяется на 4, устанавливаем время завершения работы
    IF NEW.status_id = 3 AND (OLD.status_id IS DISTINCT FROM 3) THEN
        NEW.work_ended_datetime := NOW();
    END IF;

    -- Если устанавливается время завершения работы, меняем статус на 4
    IF NEW.work_ended_datetime IS NOT NULL AND (NEW.status_id IS DISTINCT FROM 3) THEN
        NEW.status_id := 3;
    END IF;

    RETURN NEW;
END;
$$;
 :   DROP FUNCTION public.update_order_item_status_and_time();
       public               postgres    false    4                       1255    16654    update_order_status_and_time()    FUNCTION     �	  CREATE FUNCTION public.update_order_status_and_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    invalid_order_items TEXT := ''; -- Переменная для хранения сообщений о заявках с неверным статусом
BEGIN
    -- Проверка на то, чтобы все связанные order_item имели статус 3 перед сменой статуса на 4
    IF NEW.status_id = 4 THEN
        -- Находим order_item, которые не имеют статус 3, и собираем их полную информацию
        SELECT array_to_string(
                   array_agg(
                       (E'\n' || 'Заявка ID: ' || oi.id || 
                       ', Заказ ID: ' || o.id || 
                       ', Услуга: ' || s.service_name || 
                       ', Название: ' || s.service_description || 
                       ', Цена: ' || oi.price::TEXT || 
                       ', Количество: ' || oi.quantity::TEXT || 
                       ', Статус услуги: ' || st.status_name || 
                       ', Сотрудник: ' || u.first_name || ' ' || u.last_name ) 
                   ), '; ') 
        INTO invalid_order_items
        FROM order_item oi
        JOIN "order" o ON oi.order_id = o.id
        LEFT JOIN "Service" s ON oi.product_id = s.id
        LEFT JOIN status st ON oi.status_id = st.id
        LEFT JOIN employee e ON oi.employee_id = e.id
        LEFT JOIN users u ON e.user_id = u.id
        WHERE oi.order_id = NEW.id AND oi.status_id != 3;

        -- Если есть такие order_item, выводим сообщение об ошибке и отменяем изменение
        IF invalid_order_items IS NOT NULL THEN
            RAISE EXCEPTION 'Нельзя изменить статус заказа на 4. Следующие заявки не имеют статус "Выполнено": %', invalid_order_items;
        END IF;

        -- Если проверка пройдена, устанавливаем время завершения заказа
        NEW.order_finished_datetime := NOW();
    END IF;

    -- Если устанавливается время завершения, меняем статус на 4
    IF NEW.order_finished_datetime IS NOT NULL AND (NEW.status_id IS DISTINCT FROM 4) THEN
        NEW.status_id := 4;
    END IF;

    RETURN NEW;
END;
$$;
 5   DROP FUNCTION public.update_order_status_and_time();
       public               postgres    false    4                       1255    16651    update_status_and_time()    FUNCTION     *  CREATE FUNCTION public.update_status_and_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка изменения статуса на 4
    IF NEW.status_id = 4 AND (OLD.status_id IS DISTINCT FROM 4) THEN
        IF TG_TABLE_NAME = 'order' THEN
            NEW.order_finished_datetime := NOW();
        ELSIF TG_TABLE_NAME = 'order_item' THEN
            NEW.work_ended_datetime := NOW();
        END IF;
    END IF;

    -- Проверка на установку времени завершения
    IF TG_TABLE_NAME = 'order' AND NEW.order_finished_datetime IS NOT NULL THEN
        NEW.status_id := 4;
    ELSIF TG_TABLE_NAME = 'order_item' AND NEW.work_ended_datetime IS NOT NULL THEN
        NEW.status_id := 4;
    END IF;

    RETURN NEW;
END;
$$;
 /   DROP FUNCTION public.update_status_and_time();
       public               postgres    false    4            �            1259    16387    Service    TABLE     4  CREATE TABLE public."Service" (
    id bigint NOT NULL,
    service_name character varying(200) NOT NULL,
    service_description text,
    price numeric(10,2) NOT NULL,
    slug character varying(200),
    category_id bigint NOT NULL,
    image character varying(100),
    discount numeric(4,2) NOT NULL
);
    DROP TABLE public."Service";
       public         heap r       postgres    false    4            �            1259    16392    Service_id_seq    SEQUENCE     �   ALTER TABLE public."Service" ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."Service_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    217    4            �            1259    16393 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap r       postgres    false    4            �            1259    16396    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    219    4            �            1259    16397    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap r       postgres    false    4            �            1259    16400    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    221    4            �            1259    16401    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap r       postgres    false    4            �            1259    16404    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    4    223            �            1259    16405    cart    TABLE     %  CREATE TABLE public.cart (
    id bigint NOT NULL,
    quantity smallint NOT NULL,
    session_key character varying(32),
    created_timestamp timestamp with time zone NOT NULL,
    product_id bigint NOT NULL,
    user_id bigint,
    CONSTRAINT cart_quantity_check CHECK ((quantity >= 0))
);
    DROP TABLE public.cart;
       public         heap r       postgres    false    4            �            1259    16409    cart_id_seq    SEQUENCE     �   ALTER TABLE public.cart ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cart_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    225    4            �            1259    16410    category    TABLE     �   CREATE TABLE public.category (
    id bigint NOT NULL,
    category_name character varying(150) NOT NULL,
    slug character varying(200)
);
    DROP TABLE public.category;
       public         heap r       postgres    false    4            �            1259    16413    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id bigint NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);
 $   DROP TABLE public.django_admin_log;
       public         heap r       postgres    false    4            �            1259    16419    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    4    228            �            1259    16420    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap r       postgres    false    4            �            1259    16423    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    230    4            �            1259    16424    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap r       postgres    false    4            �            1259    16429    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    232    4            �            1259    16430    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap r       postgres    false    4            �            1259    16435    employee    TABLE     w   CREATE TABLE public.employee (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    user_id bigint NOT NULL
);
    DROP TABLE public.employee;
       public         heap r       postgres    false    4            �            1259    16438    employee_id_seq    SEQUENCE     �   ALTER TABLE public.employee ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    4    235            �            1259    16439    goods_category_id_seq    SEQUENCE     �   ALTER TABLE public.category ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.goods_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    227    4            �            1259    16440    order    TABLE     �  CREATE TABLE public."order" (
    id bigint NOT NULL,
    created_timestamp timestamp with time zone NOT NULL,
    phone_number character varying(20) NOT NULL,
    requires_delivery boolean NOT NULL,
    delivery_address text,
    payment_on_get boolean NOT NULL,
    comment text,
    is_paid boolean NOT NULL,
    status_id bigint,
    user_id bigint,
    delivery_date date,
    delivery_time time without time zone,
    order_finished_datetime timestamp with time zone
);
    DROP TABLE public."order";
       public         heap r       postgres    false    4            �            1259    16445    order_id_seq    SEQUENCE     �   ALTER TABLE public."order" ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    238    4            �            1259    16446 
   order_item    TABLE     �  CREATE TABLE public.order_item (
    id bigint NOT NULL,
    name character varying(150) NOT NULL,
    price numeric(7,2) NOT NULL,
    quantity integer NOT NULL,
    created_timestamp timestamp with time zone NOT NULL,
    order_id bigint NOT NULL,
    product_id bigint,
    status_id bigint NOT NULL,
    employee_id bigint,
    work_ended_datetime timestamp with time zone,
    CONSTRAINT order_item_quantity_check CHECK ((quantity >= 0))
);
    DROP TABLE public.order_item;
       public         heap r       postgres    false    4            �            1259    16450    order_item_id_seq    SEQUENCE     �   ALTER TABLE public.order_item ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    4    240            �            1259    16451    status    TABLE     �   CREATE TABLE public.status (
    id bigint NOT NULL,
    status_name character varying(150) NOT NULL,
    status_description character varying(150) NOT NULL,
    status_category character varying(150)
);
    DROP TABLE public.status;
       public         heap r       postgres    false    4            �            1259    16454    status_id_seq    SEQUENCE     �   ALTER TABLE public.status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    242    4            �            1259    16455    users    TABLE     �  CREATE TABLE public.users (
    id bigint NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(150) NOT NULL,
    first_name character varying(150) NOT NULL,
    last_name character varying(150) NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    image character varying(100)
);
    DROP TABLE public.users;
       public         heap r       postgres    false    4            �            1259    16460    users_groups    TABLE     y   CREATE TABLE public.users_groups (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    group_id integer NOT NULL
);
     DROP TABLE public.users_groups;
       public         heap r       postgres    false    4            �            1259    16463    users_groups_id_seq    SEQUENCE     �   ALTER TABLE public.users_groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    245    4            �            1259    16464    users_id_seq    SEQUENCE     �   ALTER TABLE public.users ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    4    244            �            1259    16465    users_user_permissions    TABLE     �   CREATE TABLE public.users_user_permissions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.users_user_permissions;
       public         heap r       postgres    false    4            �            1259    16468    users_user_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.users_user_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    248    4            n          0    16387    Service 
   TABLE DATA                 public               postgres    false    217   ��       p          0    16393 
   auth_group 
   TABLE DATA                 public               postgres    false    219   x�       r          0    16397    auth_group_permissions 
   TABLE DATA                 public               postgres    false    221   ��       t          0    16401    auth_permission 
   TABLE DATA                 public               postgres    false    223   ��       v          0    16405    cart 
   TABLE DATA                 public               postgres    false    225   ��       x          0    16410    category 
   TABLE DATA                 public               postgres    false    227   �       y          0    16413    django_admin_log 
   TABLE DATA                 public               postgres    false    228   ��       {          0    16420    django_content_type 
   TABLE DATA                 public               postgres    false    230   I�       }          0    16424    django_migrations 
   TABLE DATA                 public               postgres    false    232   =�                 0    16430    django_session 
   TABLE DATA                 public               postgres    false    234   ��       �          0    16435    employee 
   TABLE DATA                 public               postgres    false    235   ��       �          0    16440    order 
   TABLE DATA                 public               postgres    false    238   ,�       �          0    16446 
   order_item 
   TABLE DATA                 public               postgres    false    240    �       �          0    16451    status 
   TABLE DATA                 public               postgres    false    242   B�       �          0    16455    users 
   TABLE DATA                 public               postgres    false    244   /�       �          0    16460    users_groups 
   TABLE DATA                 public               postgres    false    245   ]�       �          0    16465    users_user_permissions 
   TABLE DATA                 public               postgres    false    248   w�       �           0    0    Service_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public."Service_id_seq"', 32, true);
          public               postgres    false    218            �           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public               postgres    false    220            �           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public               postgres    false    222            �           0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 52, true);
          public               postgres    false    224            �           0    0    cart_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.cart_id_seq', 53, true);
          public               postgres    false    226            �           0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 68, true);
          public               postgres    false    229            �           0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 14, true);
          public               postgres    false    231            �           0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 38, true);
          public               postgres    false    233            �           0    0    employee_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.employee_id_seq', 2, true);
          public               postgres    false    236            �           0    0    goods_category_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.goods_category_id_seq', 14, true);
          public               postgres    false    237            �           0    0    order_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.order_id_seq', 23, true);
          public               postgres    false    239            �           0    0    order_item_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.order_item_id_seq', 34, true);
          public               postgres    false    241            �           0    0    status_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.status_id_seq', 4, true);
          public               postgres    false    243            �           0    0    users_groups_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.users_groups_id_seq', 1, false);
          public               postgres    false    246            �           0    0    users_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.users_id_seq', 3, true);
          public               postgres    false    247            �           0    0    users_user_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.users_user_permissions_id_seq', 1, false);
          public               postgres    false    249            x           2606    16470    Service Service_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_pkey" PRIMARY KEY (id);
 B   ALTER TABLE ONLY public."Service" DROP CONSTRAINT "Service_pkey";
       public                 postgres    false    217            {           2606    16472    Service Service_slug_key 
   CONSTRAINT     W   ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_slug_key" UNIQUE (slug);
 F   ALTER TABLE ONLY public."Service" DROP CONSTRAINT "Service_slug_key";
       public                 postgres    false    217            ~           2606    16474    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public                 postgres    false    219            �           2606    16476 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public                 postgres    false    221    221            �           2606    16478 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public                 postgres    false    221            �           2606    16480    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public                 postgres    false    219            �           2606    16482 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public                 postgres    false    223    223            �           2606    16484 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public                 postgres    false    223            �           2606    16486    cart cart_pkey 
   CONSTRAINT     L   ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_pkey PRIMARY KEY (id);
 8   ALTER TABLE ONLY public.cart DROP CONSTRAINT cart_pkey;
       public                 postgres    false    225            �           2606    16488 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public                 postgres    false    228            �           2606    16490 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public                 postgres    false    230    230            �           2606    16492 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public                 postgres    false    230            �           2606    16494 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public                 postgres    false    232            �           2606    16496 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public                 postgres    false    234            �           2606    16498    employee employee_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.employee DROP CONSTRAINT employee_pkey;
       public                 postgres    false    235            �           2606    16500 )   category goods_category_category_name_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.category
    ADD CONSTRAINT goods_category_category_name_key UNIQUE (category_name);
 S   ALTER TABLE ONLY public.category DROP CONSTRAINT goods_category_category_name_key;
       public                 postgres    false    227            �           2606    16502    category goods_category_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.category
    ADD CONSTRAINT goods_category_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.category DROP CONSTRAINT goods_category_pkey;
       public                 postgres    false    227            �           2606    16504     category goods_category_slug_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.category
    ADD CONSTRAINT goods_category_slug_key UNIQUE (slug);
 J   ALTER TABLE ONLY public.category DROP CONSTRAINT goods_category_slug_key;
       public                 postgres    false    227            �           2606    16506    order_item order_item_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.order_item DROP CONSTRAINT order_item_pkey;
       public                 postgres    false    240            �           2606    16508    order order_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public."order" DROP CONSTRAINT order_pkey;
       public                 postgres    false    238            �           2606    16510    status status_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.status
    ADD CONSTRAINT status_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.status DROP CONSTRAINT status_pkey;
       public                 postgres    false    242            �           2606    16512    users_groups users_groups_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.users_groups DROP CONSTRAINT users_groups_pkey;
       public                 postgres    false    245            �           2606    16514 8   users_groups users_groups_user_id_group_id_fc7788e8_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_user_id_group_id_fc7788e8_uniq UNIQUE (user_id, group_id);
 b   ALTER TABLE ONLY public.users_groups DROP CONSTRAINT users_groups_user_id_group_id_fc7788e8_uniq;
       public                 postgres    false    245    245            �           2606    16516    users users_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
       public                 postgres    false    244            �           2606    16518 2   users_user_permissions users_user_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.users_user_permissions DROP CONSTRAINT users_user_permissions_pkey;
       public                 postgres    false    248            �           2606    16520 Q   users_user_permissions users_user_permissions_user_id_permission_id_3b86cbdf_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissions_user_id_permission_id_3b86cbdf_uniq UNIQUE (user_id, permission_id);
 {   ALTER TABLE ONLY public.users_user_permissions DROP CONSTRAINT users_user_permissions_user_id_permission_id_3b86cbdf_uniq;
       public                 postgres    false    248    248            �           2606    16522    users users_username_key 
   CONSTRAINT     W   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);
 B   ALTER TABLE ONLY public.users DROP CONSTRAINT users_username_key;
       public                 postgres    false    244            v           1259    16523    Service_category_id_fcdfa058    INDEX     [   CREATE INDEX "Service_category_id_fcdfa058" ON public."Service" USING btree (category_id);
 2   DROP INDEX public."Service_category_id_fcdfa058";
       public                 postgres    false    217            y           1259    16524    Service_slug_cab46943_like    INDEX     f   CREATE INDEX "Service_slug_cab46943_like" ON public."Service" USING btree (slug varchar_pattern_ops);
 0   DROP INDEX public."Service_slug_cab46943_like";
       public                 postgres    false    217            |           1259    16525    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public                 postgres    false    219            �           1259    16526 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public                 postgres    false    221            �           1259    16527 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public                 postgres    false    221            �           1259    16528 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public                 postgres    false    223            �           1259    16529    cart_product_id_508e72da    INDEX     O   CREATE INDEX cart_product_id_508e72da ON public.cart USING btree (product_id);
 ,   DROP INDEX public.cart_product_id_508e72da;
       public                 postgres    false    225            �           1259    16530    cart_user_id_1361a739    INDEX     I   CREATE INDEX cart_user_id_1361a739 ON public.cart USING btree (user_id);
 )   DROP INDEX public.cart_user_id_1361a739;
       public                 postgres    false    225            �           1259    16531 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public                 postgres    false    228            �           1259    16532 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public                 postgres    false    228            �           1259    16533 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public                 postgres    false    234            �           1259    16534 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public                 postgres    false    234            �           1259    16535    employee_category_id_9af3e737    INDEX     Y   CREATE INDEX employee_category_id_9af3e737 ON public.employee USING btree (category_id);
 1   DROP INDEX public.employee_category_id_9af3e737;
       public                 postgres    false    235            �           1259    16536    employee_user_id_cc4f5a1c    INDEX     Q   CREATE INDEX employee_user_id_cc4f5a1c ON public.employee USING btree (user_id);
 -   DROP INDEX public.employee_user_id_cc4f5a1c;
       public                 postgres    false    235            �           1259    16537 *   goods_category_category_name_7b12da53_like    INDEX     |   CREATE INDEX goods_category_category_name_7b12da53_like ON public.category USING btree (category_name varchar_pattern_ops);
 >   DROP INDEX public.goods_category_category_name_7b12da53_like;
       public                 postgres    false    227            �           1259    16538 !   goods_category_slug_370bc312_like    INDEX     j   CREATE INDEX goods_category_slug_370bc312_like ON public.category USING btree (slug varchar_pattern_ops);
 5   DROP INDEX public.goods_category_slug_370bc312_like;
       public                 postgres    false    227            �           1259    16539    order_item_employee_id_193da51a    INDEX     ]   CREATE INDEX order_item_employee_id_193da51a ON public.order_item USING btree (employee_id);
 3   DROP INDEX public.order_item_employee_id_193da51a;
       public                 postgres    false    240            �           1259    16540    order_item_order_id_0ca9e92e    INDEX     W   CREATE INDEX order_item_order_id_0ca9e92e ON public.order_item USING btree (order_id);
 0   DROP INDEX public.order_item_order_id_0ca9e92e;
       public                 postgres    false    240            �           1259    16541    order_item_product_id_62a1cc4c    INDEX     [   CREATE INDEX order_item_product_id_62a1cc4c ON public.order_item USING btree (product_id);
 2   DROP INDEX public.order_item_product_id_62a1cc4c;
       public                 postgres    false    240            �           1259    16542    order_item_status_id_755fd168    INDEX     Y   CREATE INDEX order_item_status_id_755fd168 ON public.order_item USING btree (status_id);
 1   DROP INDEX public.order_item_status_id_755fd168;
       public                 postgres    false    240            �           1259    16543    order_status_id_cd54252a    INDEX     Q   CREATE INDEX order_status_id_cd54252a ON public."order" USING btree (status_id);
 ,   DROP INDEX public.order_status_id_cd54252a;
       public                 postgres    false    238            �           1259    16544    order_user_id_e323497c    INDEX     M   CREATE INDEX order_user_id_e323497c ON public."order" USING btree (user_id);
 *   DROP INDEX public.order_user_id_e323497c;
       public                 postgres    false    238            �           1259    16545    users_groups_group_id_2f3517aa    INDEX     [   CREATE INDEX users_groups_group_id_2f3517aa ON public.users_groups USING btree (group_id);
 2   DROP INDEX public.users_groups_group_id_2f3517aa;
       public                 postgres    false    245            �           1259    16546    users_groups_user_id_f500bee5    INDEX     Y   CREATE INDEX users_groups_user_id_f500bee5 ON public.users_groups USING btree (user_id);
 1   DROP INDEX public.users_groups_user_id_f500bee5;
       public                 postgres    false    245            �           1259    16547 -   users_user_permissions_permission_id_6d08dcd2    INDEX     y   CREATE INDEX users_user_permissions_permission_id_6d08dcd2 ON public.users_user_permissions USING btree (permission_id);
 A   DROP INDEX public.users_user_permissions_permission_id_6d08dcd2;
       public                 postgres    false    248            �           1259    16548 '   users_user_permissions_user_id_92473840    INDEX     m   CREATE INDEX users_user_permissions_user_id_92473840 ON public.users_user_permissions USING btree (user_id);
 ;   DROP INDEX public.users_user_permissions_user_id_92473840;
       public                 postgres    false    248            �           1259    16549    users_username_e8658fc8_like    INDEX     f   CREATE INDEX users_username_e8658fc8_like ON public.users USING btree (username varchar_pattern_ops);
 0   DROP INDEX public.users_username_e8658fc8_like;
       public                 postgres    false    244            �           2620    16657 (   order_item update_order_item_status_time    TRIGGER     �   CREATE TRIGGER update_order_item_status_time BEFORE UPDATE ON public.order_item FOR EACH ROW EXECUTE FUNCTION public.update_order_item_status_and_time();
 A   DROP TRIGGER update_order_item_status_time ON public.order_item;
       public               postgres    false    240    262            �           2620    16655    order update_order_status_time    TRIGGER     �   CREATE TRIGGER update_order_status_time BEFORE UPDATE ON public."order" FOR EACH ROW EXECUTE FUNCTION public.update_order_status_and_time();
 9   DROP TRIGGER update_order_status_time ON public."order";
       public               postgres    false    238    263            �           2606    16550 3   Service Service_category_id_fcdfa058_fk_category_id    FK CONSTRAINT     �   ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_category_id_fcdfa058_fk_category_id" FOREIGN KEY (category_id) REFERENCES public.category(id) DEFERRABLE INITIALLY DEFERRED;
 a   ALTER TABLE ONLY public."Service" DROP CONSTRAINT "Service_category_id_fcdfa058_fk_category_id";
       public               postgres    false    217    4756    227            �           2606    16555 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public               postgres    false    4747    221    223            �           2606    16560 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public               postgres    false    4736    219    221            �           2606    16565 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public               postgres    false    4767    223    230            �           2606    16570 +   cart cart_product_id_508e72da_fk_Service_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.cart
    ADD CONSTRAINT "cart_product_id_508e72da_fk_Service_id" FOREIGN KEY (product_id) REFERENCES public."Service"(id) DEFERRABLE INITIALLY DEFERRED;
 W   ALTER TABLE ONLY public.cart DROP CONSTRAINT "cart_product_id_508e72da_fk_Service_id";
       public               postgres    false    217    4728    225            �           2606    16575 &   cart cart_user_id_1361a739_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_user_id_1361a739_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 P   ALTER TABLE ONLY public.cart DROP CONSTRAINT cart_user_id_1361a739_fk_users_id;
       public               postgres    false    4791    244    225            �           2606    16580 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public               postgres    false    4767    228    230            �           2606    16585 >   django_admin_log django_admin_log_user_id_c564eba6_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_id;
       public               postgres    false    244    228    4791            �           2606    16590 5   employee employee_category_id_9af3e737_fk_category_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_category_id_9af3e737_fk_category_id FOREIGN KEY (category_id) REFERENCES public.category(id) DEFERRABLE INITIALLY DEFERRED;
 _   ALTER TABLE ONLY public.employee DROP CONSTRAINT employee_category_id_9af3e737_fk_category_id;
       public               postgres    false    4756    235    227            �           2606    16595 .   employee employee_user_id_cc4f5a1c_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_user_id_cc4f5a1c_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 X   ALTER TABLE ONLY public.employee DROP CONSTRAINT employee_user_id_cc4f5a1c_fk_users_id;
       public               postgres    false    244    4791    235            �           2606    16600 9   order_item order_item_employee_id_193da51a_fk_employee_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_employee_id_193da51a_fk_employee_id FOREIGN KEY (employee_id) REFERENCES public.employee(id) DEFERRABLE INITIALLY DEFERRED;
 c   ALTER TABLE ONLY public.order_item DROP CONSTRAINT order_item_employee_id_193da51a_fk_employee_id;
       public               postgres    false    4776    235    240            �           2606    16605 3   order_item order_item_order_id_0ca9e92e_fk_order_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_order_id_0ca9e92e_fk_order_id FOREIGN KEY (order_id) REFERENCES public."order"(id) DEFERRABLE INITIALLY DEFERRED;
 ]   ALTER TABLE ONLY public.order_item DROP CONSTRAINT order_item_order_id_0ca9e92e_fk_order_id;
       public               postgres    false    240    238    4779            �           2606    16610 7   order_item order_item_product_id_62a1cc4c_fk_Service_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT "order_item_product_id_62a1cc4c_fk_Service_id" FOREIGN KEY (product_id) REFERENCES public."Service"(id) DEFERRABLE INITIALLY DEFERRED;
 c   ALTER TABLE ONLY public.order_item DROP CONSTRAINT "order_item_product_id_62a1cc4c_fk_Service_id";
       public               postgres    false    217    240    4728            �           2606    16658 5   order_item order_item_status_id_755fd168_fk_status_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_status_id_755fd168_fk_status_id FOREIGN KEY (status_id) REFERENCES public.status(id) DEFERRABLE INITIALLY DEFERRED;
 _   ALTER TABLE ONLY public.order_item DROP CONSTRAINT order_item_status_id_755fd168_fk_status_id;
       public               postgres    false    242    240    4789            �           2606    16620 +   order order_status_id_cd54252a_fk_status_id    FK CONSTRAINT     �   ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_status_id_cd54252a_fk_status_id FOREIGN KEY (status_id) REFERENCES public.status(id) DEFERRABLE INITIALLY DEFERRED;
 W   ALTER TABLE ONLY public."order" DROP CONSTRAINT order_status_id_cd54252a_fk_status_id;
       public               postgres    false    242    238    4789            �           2606    16625 (   order order_user_id_e323497c_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_user_id_e323497c_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 T   ALTER TABLE ONLY public."order" DROP CONSTRAINT order_user_id_e323497c_fk_users_id;
       public               postgres    false    4791    238    244            �           2606    16630 <   users_groups users_groups_group_id_2f3517aa_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_group_id_2f3517aa_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 f   ALTER TABLE ONLY public.users_groups DROP CONSTRAINT users_groups_group_id_2f3517aa_fk_auth_group_id;
       public               postgres    false    4736    245    219            �           2606    16635 6   users_groups users_groups_user_id_f500bee5_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_user_id_f500bee5_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 `   ALTER TABLE ONLY public.users_groups DROP CONSTRAINT users_groups_user_id_f500bee5_fk_users_id;
       public               postgres    false    244    245    4791            �           2606    16640 O   users_user_permissions users_user_permissio_permission_id_6d08dcd2_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissio_permission_id_6d08dcd2_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.users_user_permissions DROP CONSTRAINT users_user_permissio_permission_id_6d08dcd2_fk_auth_perm;
       public               postgres    false    4747    248    223            �           2606    16645 J   users_user_permissions users_user_permissions_user_id_92473840_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissions_user_id_92473840_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.users_user_permissions DROP CONSTRAINT users_user_permissions_user_id_92473840_fk_users_id;
       public               postgres    false    248    4791    244            n   �  x��U�n�P��+,6i%\�"V-�DD�J�-���ƹ�Ək�Nh�jS� �Ab��?p�Q܆_��#ε�Jq�WX8�;3��s�̸T���ؔJ���m�,C�P�^���i{e}k�"ͪ�C)ǿ��.��w� ��q����nK��/<B�w��v����a��w���|���:D�g�=֒�E��c-j1�-"��Xݯ6iP��"T��ynטּ�o���]sOfJw�X~�� �+ t�w8���x?q���(>�P�1@#�ws���$��#�8�����A.�F�ꎡ��7q`5�j��F�8��\)Y�j���,Z}��n-y�C�
�!KY��f�=��x�����a\��p��z� ��b�g�AL�i7�6�JH������k�����T�(?��Ct�/���~������`��\t| ���s��������",�ş��R9��8�$�n�d@:��[�X�����)�EȿA�!�z! ��^
�E��غ�Ź�$��Afk�'$����Q�3.I���0?0�C�e4H@!�
�&�`��U+����zeE��O�o�g��6����G;!88��O�,\��w��F�$�$��K��y~�ن���,ߧ���DU^�)"FV�/��
�S�΍e^���0�;�lb~��a[�KS;�J�W��	�Ge�y�� %YM��%4������'���š�E|֊���jYW�q33� �{�E      p   
   x���          r   
   x���          t   �  x����j�@��~��%�PlY��U(YJ
M�mP��ؖ����x[�e����iqHp�a�FIG�܄=�r����'�zv���O�ߓY�y�^{qty1��ğ��`J>��xrFG��7%�pH����i.�H:�>�G�����c�.��j�|��7>�c��|��� ���������˟9؁����-����m4�#���p4�+V�ѳ�����(��6���w;^�.�-2�g�!w,b�^���Y�(dShtL#~H��Qv�XgSK�+�k����h�]2��=2�b񆄬�=�asZܗ,��XB�r�2zG�{r�2�ơ��X��ZFbE3��l�ܰ�='��!����i�":
��8�2�8��Ŗ�1řG�Hެɏ=2B4(��|eOɒ�'K��?�����Qj����Wj��W ŗj��=@�E��_왣��5��v����.l �1��s�S���*0A�e��N0A�w��d����&fw���$�|�ن=�GN��N�d6�v�MEƕ�l�����6FRreH�lDGvF��o���J_ �0�Ȗ��da������4K��"��n]у�n�gK���V��)�x�¡��rU?kd�W����k\v��ΊF�[Ʀ�g�.2�%ɲpO�WG\�щm�j�]C��`rUc�+���5�nK��F1���︝��Ҕ�^�+�#/��_y�b7��+_���_<X��������d�j���      v   _   x���v
Q���W((M��L�KN,*Qs�	uV�05�Q0�Q����QP7202�54�52V04�22�20�3�4��4�60V�Q0*5Ҵ��� �:      x   �   x���v
Q���W((M��L�KN,IM�/�Ts�	uV�0�QP�0�bㅭ
�����6_ءN��Q״��$�#�)�^�}aА��[@�����g��k�1Ȩ�6\�sa߅]6\lS�����XB�!& C�]��®�M��B325'5��(�D�M1L��	������}3L󁮾��m@�w]؍dzn~I~rf68��� ����      y   E  x��[�nE��+Z� �u�n��,"!�xmB����� +@
	/	E�BX#��e��z~�/�V�������g�3Qҙt;����sou_x��_~5���/e�}�v��:�xg��[��\�x���7�\{+{��^{���qx*{Lp�灟��˕ɕb�h'��\>F? �P�0����F7�����b7�ߣ���N�=�>��~��ŏVV7667V��O>�Dg5]x�s� &b`6犡�ULT���b��O�v����,q� �4���8�Cq��.�%6����Ā)�2�$W�����1�S�n�����	�J!��)m�=5"#�H���t
��@�m|���#ǣ/�^�?KL&��r��\'����B�_ܣ�O������ї��S��O���:��&��w�G����i`�7�v�<��SK6��N:ަ�����xY	}�4b{�8]�rp�Q�Z�I�_��>9�nx�>Sv|�;F�)�
��Z���*\�e"r�`����?���ʐ�^�:$�@��ȥ`ȍ0����ĻM�ۍ���+b�2�0Ju
BHtM�����elj�B�$J�&<L������{�ޭ��K w���/#>Tb�Z������Leڵ{���ӢB��6ݠ²�uy��������r���<��(�3�U[�ʥ��z뜠X�9(&pl��ƙ�qL�Q��t���OH��Z��ZA�����r��.<��X;+'��(��fy���È1-#&���0O����m
��s-��
8x�=��rI�����d>h�>}�
��h��Ӣ6��r�zr
���$�8X��US'�B�E�pa'i���3+�q
	�)��ԍx���=�$`�Ǭ��o����;�L��	��K�hU��s�����O�z�xbń��5C�N��4�M��^�f9�� �d�g��^�3���Sc��a��D������\3F�B%���_���o�(0;����Z���>�1+��M�� ����2���[��Thί<�M�0�3h���Ȫ��G�����Ĩ1Y��6��{թ��'r�����X検3�
�"�6F1�\+�U���{@��t<h��7Yv�!�x�+%�s�^��g/����'�υ�sp@Rϲ3|
�:Lf�Ȁ!C��@$�%�t��	�+��e��j�(�a���m�V� =���"A�L#K{���b��DG{"eOέ��;���;�	\qب�G�:@�c����i�+���;���g���k��1��X�A�ֱ
r	�èY@�ˉぜJ�uP��{h:�&�Q���Q���1Q`sj�,纳��o\F_�jI�+����.�S�P2-��'�q}ıԄ�2�ri�g�+��N��&o�r���<�$"`�˱(�m��h��*ߔ� �!�+���-&z��2�����ȟh�<�L�$�1΅1S{y�'��͜P̴�mɧJ�I}cĐ	ܒRRjKJ�, a�-�a�?a=�~��*�!�uZ��}�f��v�;;`�k~k-��P�ڈzEԓ�ܴs�z�m�zI}�zץ �#0��x# �������?��\(?iQh�U���B&�Dc-.D̅����qMy?H5��NjZ�[�ߞ#���ѷt��bL�Lq៹��ԩ3�ݡ0��?��H�)}��z�J�N�W:.����lG��Ǹ$��JԄ2�톅[j��L�/�GcE�a�֪%�ȷ)�%0�$@K��ɟrP�t��
�;�壟j_����n�>���Kɰ[�>.F��}/���d;C\V����¿1��I��Y��4��3�~�Pᵢs;;�"N���\��ҿAF����N{�&Π`]]}w�>TIuH!
r$L����Tn�_[{gs���v�MR˯�7�m�@6�_Q;ц� ��˲��V��}��]��ެ��!���߾���.�@Xh�n�����B؅�^=�����V]6�@2@�R�ư���N
�P+d�HR✛J!d��]��LŔV8�ͦ�WL��[���%�Q��$"��<;ŝQ�&ŉ0-��f2g��MzԪ:���e9����X�w[����L����1�=ߣ�O�,�>�m*��d��r���ܹ�丌0      {   �   x������0�{�"�*,���U<y�P��ݫ�v��6��з7�=T����&���!����9�|:�.�,?�[�j<����� �6���Q���U+U�C����t�x���9��8�F�i����ڠ������ܦ��q�q����!-�\�ճ���F�¿��s�%g���v�<2!0��ЀV7���lWb�ߍ!^4��o'&3��H��C�^(K9�$y �2G      }   �  x����r�6��~
vN*q����b�JM�2�lU�F�(��3~���#��Ϧ/���׹��<~�������Ͽ����o7�߶��i}��C���۟>?����:���OB����6�w�{����ђ፠����?�r���P��fp�l�����`�4n��� .͸4������Cg[glW�6�e}L*�!�X�����.>���Ȼ�񭭗upL9H�tp]�\��zCъCd�L�� +�oþ�����eƔ��H��e=JS
ѣ�?nC7�n�wn}s
����<�\j�x͌�,�k
JF�/�~��z��j�-�S�يv.���ӽǦo�wӸ�>�8��k.@�T�ٖ����k�oV�5���S<�ŏ/� �
_.o����M�����~0M�}���YN��H�S�H5����K���e�g��XL�g�y����b���2.�M��>Y�+	��ZMNe���(?�)�%AM�%�R�DXH�=���IB�~�υ���v����R	8�����-�_"�����0���W�~��� �����O7I"�T���U��V���0{!,c��͒��c��a�"�>_�s�%,�<��+|4��7_[����1��Ź@�Mnk�>���UKf��T��hR"
;��ѾB��S�J#؀@t����r�r)ţ��]s�Q�	P����zw5�5�PH
�y8��;�������±��8.���%�� n?l��1�񒢍�)��`7!p��	�n&�'��P.˹|&ҷK�	"�$�Dc�`B`#>��E���u1��%&*��<�(9m��B�Ǹ�rյqg�����mP��`�=��uN���<�^���b�R�Iu��@_إ^S0yf�U`\rVR�BA�:�^ww�ָ��         �  x���ɒ�6���}
�:��.$�d�x��M��Q̘�৏{��Ce�{wy ���Jg������떱�~��0�*Z�]�ui]-.�ۻr^��"��kz��{&�؆��y�S��)h�Oڗ?/bD�-݉��M��x���6���՚] ��(�V���`d��y2�]f��@B�@�`��^~�������'US�+��\��iȓ ���wg�oJ�&�[������ ��8��yw��r����O��c?�"q"�+����$����;�}��B1�,����mhk�[w�Q�".��&����j:d�&�y|�Q�ڦ��o�Xd���R��	��5�MH(y�#�(�T�;��U�}-��;�C>�"��Q��N�*�wֻ����S��U�~����,� X����� �_0ej: ^I�ʣiE�`�kp�z��Ut�.���T2O�R����L�0�o維�k�^���ݤ1D�ш�R��݀*?���9��O�iWL(78�g��Yv��[ҬC+EA�5r+[Y�'��N��@3��_Us��{~{�R���^�^a3�τY�东ݕ>Y� �e��d�'|.���<N���+�֔�Z����yW�?�BFd��' ~��y��X�SYT�-j[���@�˿��O�L2ב�n����9������^s����Ɩ�i.�����mh��l�`�d�cM�QV79Ty�j=�s��G<^�7�xy�*��4�$�F�vq6f�Y$�o�T��TfXeD����Gy�uWy��ؾ������ji�lP{K*0�Z,�O��BQ�IyG�߱�OV���
�~ �i�����%�o��S/���8��W��yS��kr�SϮ��v��P����Ԗ��YIk�6������D����#��?�JcFh3��l\	(+���e�$��x�SV���p,=;������#�t)ܮlq�ܪ�������7�7����X/��ϣ^�/�ւ�      �   B   x���v
Q���W((M��L�K�-�ɯLMUs�	uV�0�Q0�Q0Դ��$B5P�1PP5 =�t      �   �  x���Ko1���V/�X�{��ġ�JU�h˝G��*���B*�#U�� T)�O���1�l��&�I��d^k����=����������D��y���\x�z��Z��n.��� Kb�&�&�@���!N?T��<y��(~z�|��Vn�a�%��e:n�94V��
����m��>x�X��2�#�xI�bVB�[)/�q�7�/KQX���ώ���G��Ck����^�f�]����;��]������<���%�>�;�՘����a0YBS ���X_���r�w�9E�����z��S��5����`<���o��BM���rU��4� �@$�p��TOY3W���Ay	�:�J�փ����;d�s.�I<��Q�
�̬�o�6�s�m�}ߋ�EF����AtM�>�#��.�Ze`�KM\�3��������i����Y˽�����R ��Y�hGh�.�V#��'��-�(�y��I�=D�Iʣ���ߘ���::�gV�O@,l&�Xwչ�|���N&,��N�xr�2�̕BU���4
,���C�9�2Mc��]xa��r�� RvM�s�LEV���$�#gC
1��hI�'�Wd�0"m2�����4�9rV��>M݇�2�8G+Ͱ����wء>����ڏ�������-\�.�i�B'�y�/�b$�z�>;YoN
�/�5 wa��      �   2  x����n�@��}
�
��v>v�kNz�T��\��*�@��"���'�Ah	D��+�߈Y;�����F��Ȏ&�����d}sk��v����0y��鋽g����O���L?��Y�J��d��=��������_ry���q��� +�*%'�
y�*R�*W6'�jr`���,A�e����F�~����L8@����Th.|?���r1(>�١���/�8-��?~���	$��� QO��D�\�K�F�C�f�Ѹe�~H�B�΋�D��\�'�y���&
�c�BA�����ӡJ���8->���[�۸�W�e׷�'ٰX�rݦ���b�Q8����RKBm�`��8�ppj�d��Q<Kc�PZM����-��aU� ��\��-��v��G�!�4�i�h�� -.��W��g4 OE1�P%� X��/R*=J�8��*��"�@>�*�9��d��`��l0c+�i(���(���
��7 �S&V�@wrh�ͅ9r����Ţ�nx�r(Mw9g�3�vk4f�*'b����
R��=�2�Y�#����c��b�\�\J�"�&��]l�dN+nHV�BW�y�hq��t��#0�
�2"����J���{U��b&h�>e���WaT�_�&�'� �ΓhT�J�tQ*�l%9b��2=���$�'"�bA\N6U�A=*�0� �ȅ0T/s��cG��$!~!!��hMV��>P����n4I�i9a b� ���4@�`��\��b�ZB�?@[�@��q©�w���y��S�;l
h��wuu�mN�rκу,-�HMv�      �   �   x��P;
�P�s��� �����" 
�z�,M��K/��I�����I���cv>�h�v��!��i�D�G��t֟�S�U��Z�2����a������k\��s6���e��c�Dl�D'�ޅw��f+��5���b���l1��u����^HԆ��[R�T��]�jF���X�����U-�C��96����(��w��M��':*����      �     x����n�@��y
/"T�Ό=�	�I�s�9%�T�L'�%N�8;�+$� o��.(}�p.\RT�Y�9����|s�z���2j��`�:&���,bzJU+u�G�	���5DW�HGXȊ�'�2��{�7 �:�P��=�U�zcA(�V�]���R�k�1�օX��uK��Z�r�� >a��d$ɐgy A�� .u7����t�O>$ߒ�Mr��6���v{��6���mOw\��?��ق��yH�d�e^`S ŽUn7����6=536]ʎC;��iF}�w'�u�ج��5�J��B3\f��v�E ��{`uY�)j�JZ�28/W�j�M�kE�ڪ�q���@�s�w0Q�1G4:����y��>n^o�$�6o���m�J��D��g�I�y�Gу�~����	�cABҁ��B�.T�a#�3_��ش�\�يg��U���F�m���~>o�Tz�2�`՜FG���eHd�X�	 R�a����;.�/���:��7ҭTtDd_}w�J2��Pd�%H������      �   
   x���          �   
   x���         