PGDMP                      |            postgres    17.2    17.2 �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                           false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                           false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                           false            �           1262    5    postgres    DATABASE     }   CREATE DATABASE postgres WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'Russian_Moldova.1251';
    DROP DATABASE postgres;
                     postgres    false            �           0    0    DATABASE postgres    COMMENT     N   COMMENT ON DATABASE postgres IS 'default administrative connection database';
                        postgres    false    5022                        2615    2200    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
                     pg_database_owner    false            �           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                        pg_database_owner    false    4                       1255    16700 %   check_employee_before_status_change()    FUNCTION     �  CREATE FUNCTION public.check_employee_before_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем, пытаются ли изменить статус на "Выполнено" или "В работе"
    IF NEW.status_id IN (
        SELECT id FROM status WHERE status_name IN ('Выполнено', 'В работе')
    ) THEN
        -- Проверяем, что сотрудник назначен (employee_id не может быть NULL)
        IF NEW.employee_id IS NULL THEN
            RAISE EXCEPTION 'Невозможно изменить статус на "Выполнено" или "В работе", пока не назначен сотрудник';
        END IF;
    END IF;

    -- Возвращаем новую запись (она будет сохранена в базе данных)
    RETURN NEW;
END;
$$;
 <   DROP FUNCTION public.check_employee_before_status_change();
       public               postgres    false    4            �            1255    16702 !   check_employee_service_category()    FUNCTION     �  CREATE FUNCTION public.check_employee_service_category() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Получаем категорию сотрудника
    IF (SELECT category_id FROM employee WHERE id = NEW.employee_id) !=
       (SELECT category_id FROM "Service" WHERE id = NEW.product_id) THEN
        RAISE EXCEPTION 'Категория сотрудника и услуги не совпадают.';
    END IF;
    RETURN NEW;
END;
$$;
 8   DROP FUNCTION public.check_employee_service_category();
       public               postgres    false    4            �            1255    16683 #   update_order_item_status_and_time()    FUNCTION     �  CREATE FUNCTION public.update_order_item_status_and_time() RETURNS trigger
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
       public               postgres    false    4                       1255    16696 )   update_order_item_status_to_in_progress()    FUNCTION       CREATE FUNCTION public.update_order_item_status_to_in_progress() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем, что сотрудник назначен (не NULL)
    IF NEW.employee_id IS NOT NULL THEN
        -- Меняем статус заявки на "В работе"
        UPDATE order_item
        SET status_id = (SELECT id FROM status WHERE status_name = 'В работе' AND status_category = 'Услуга')
        WHERE id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$;
 @   DROP FUNCTION public.update_order_item_status_to_in_progress();
       public               postgres    false    4            �            1255    16684    update_order_status_and_time()    FUNCTION     �	  CREATE FUNCTION public.update_order_status_and_time() RETURNS trigger
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
       public               postgres    false    4            
           1255    16690 $   update_order_status_based_on_items()    FUNCTION     	  CREATE FUNCTION public.update_order_status_based_on_items() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем, есть ли хотя бы одна заявка с статусом "В работе"
    IF EXISTS (
        SELECT 1
        FROM order_item
        WHERE order_id = NEW.order_id
        AND status_id = (SELECT id FROM status WHERE status_name = 'В работе')
    ) THEN
        -- Если хотя бы одна заявка в статусе "В работе", меняем статус заказа на "Выполняется"
        UPDATE "order"
        SET status_id = (SELECT id FROM status WHERE status_name = 'Выполняется')
        WHERE id = NEW.order_id;
    -- Если все заявки имеют статус "Выполнено", меняем статус заказа на "Завершено"
    ELSIF NOT EXISTS (
        SELECT 1
        FROM order_item
        WHERE order_id = NEW.order_id
        AND status_id != (SELECT id FROM status WHERE status_name = 'Выполнено')
    ) THEN
        UPDATE "order"
        SET status_id = (SELECT id FROM status WHERE status_name = 'Завершено')
        WHERE id = NEW.order_id;
    END IF;
    RETURN NEW;
END;
$$;
 ;   DROP FUNCTION public.update_order_status_based_on_items();
       public               postgres    false    4            �            1255    16688 ,   update_order_status_if_all_items_completed()    FUNCTION     �  CREATE FUNCTION public.update_order_status_if_all_items_completed() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверяем, все ли заявки в заказе имеют статус "Выполнено"
    IF NOT EXISTS (
        SELECT 1
        FROM order_item
        WHERE order_id = NEW.order_id
        AND status_id != (SELECT id FROM status WHERE status_name = 'Выполнено')
    ) THEN
        -- Если все заявки выполнены, меняем статус заказа на "Завершено"
        UPDATE "order"
        SET status_id = (SELECT id FROM status WHERE status_name = 'Завершено')
        WHERE id = NEW.order_id;
    END IF;
    RETURN NEW;
END;
$$;
 C   DROP FUNCTION public.update_order_status_if_all_items_completed();
       public               postgres    false    4            �            1255    16685    update_status_and_time()    FUNCTION     *  CREATE FUNCTION public.update_status_and_time() RETURNS trigger
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
       public               postgres    false    4            �            1259    16409    Service    TABLE     4  CREATE TABLE public."Service" (
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
       public         heap r       postgres    false    4            �            1259    16408    Service_id_seq    SEQUENCE     �   ALTER TABLE public."Service" ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public."Service_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    222    4            �            1259    16441 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap r       postgres    false    4            �            1259    16440    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    4    228            �            1259    16449    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap r       postgres    false    4            �            1259    16448    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    230    4            �            1259    16435    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap r       postgres    false    4            �            1259    16434    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    226    4            �            1259    16571    cart    TABLE     %  CREATE TABLE public.cart (
    id bigint NOT NULL,
    quantity smallint NOT NULL,
    session_key character varying(32),
    created_timestamp timestamp with time zone NOT NULL,
    product_id bigint NOT NULL,
    user_id bigint,
    CONSTRAINT cart_quantity_check CHECK ((quantity >= 0))
);
    DROP TABLE public.cart;
       public         heap r       postgres    false    4            �            1259    16570    cart_id_seq    SEQUENCE     �   ALTER TABLE public.cart ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cart_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    242    4            �            1259    16397    category    TABLE     �   CREATE TABLE public.category (
    id bigint NOT NULL,
    category_name character varying(150) NOT NULL,
    slug character varying(200)
);
    DROP TABLE public.category;
       public         heap r       postgres    false    4            �            1259    16550    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
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
       public         heap r       postgres    false    4            �            1259    16549    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    4    240            �            1259    16427    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap r       postgres    false    4            �            1259    16426    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    4    224            �            1259    16389    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap r       postgres    false    4            �            1259    16388    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    218    4            �            1259    16673    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap r       postgres    false    4            �            1259    16503    employee    TABLE     w   CREATE TABLE public.employee (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    user_id bigint NOT NULL
);
    DROP TABLE public.employee;
       public         heap r       postgres    false    4            �            1259    16502    employee_id_seq    SEQUENCE     �   ALTER TABLE public.employee ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.employee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    238    4            �            1259    16396    goods_category_id_seq    SEQUENCE     �   ALTER TABLE public.category ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.goods_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    220    4            �            1259    16590    order    TABLE     �  CREATE TABLE public."order" (
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
       public         heap r       postgres    false    4            �            1259    16589    order_id_seq    SEQUENCE     �   ALTER TABLE public."order" ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    244    4            �            1259    16598 
   order_item    TABLE     �  CREATE TABLE public.order_item (
    id bigint NOT NULL,
    name character varying(150) NOT NULL,
    price numeric(7,2) NOT NULL,
    quantity integer NOT NULL,
    created_timestamp timestamp with time zone NOT NULL,
    order_id bigint NOT NULL,
    product_id bigint,
    status_id bigint,
    employee_id bigint,
    work_ended_datetime timestamp with time zone,
    CONSTRAINT order_item_quantity_check CHECK ((quantity >= 0))
);
    DROP TABLE public.order_item;
       public         heap r       postgres    false    4            �            1259    16597    order_item_id_seq    SEQUENCE     �   ALTER TABLE public.order_item ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.order_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    4    246            �            1259    16623    status    TABLE     �   CREATE TABLE public.status (
    id bigint NOT NULL,
    status_name character varying(150) NOT NULL,
    status_description character varying(150) NOT NULL,
    status_category character varying(150)
);
    DROP TABLE public.status;
       public         heap r       postgres    false    4            �            1259    16622    status_id_seq    SEQUENCE     �   ALTER TABLE public.status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    4    248            �            1259    16481    users    TABLE     �  CREATE TABLE public.users (
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
       public         heap r       postgres    false    4            �            1259    16491    users_groups    TABLE     y   CREATE TABLE public.users_groups (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    group_id integer NOT NULL
);
     DROP TABLE public.users_groups;
       public         heap r       postgres    false    4            �            1259    16490    users_groups_id_seq    SEQUENCE     �   ALTER TABLE public.users_groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    234    4            �            1259    16480    users_id_seq    SEQUENCE     �   ALTER TABLE public.users ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    232    4            �            1259    16497    users_user_permissions    TABLE     �   CREATE TABLE public.users_user_permissions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.users_user_permissions;
       public         heap r       postgres    false    4            �            1259    16496    users_user_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.users_user_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.users_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public               postgres    false    236    4            }          0    16409    Service 
   TABLE DATA           u   COPY public."Service" (id, service_name, service_description, price, slug, category_id, image, discount) FROM stdin;
    public               postgres    false    222   �       �          0    16441 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public               postgres    false    228   �       �          0    16449    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public               postgres    false    230   ��       �          0    16435    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public               postgres    false    226   ��       �          0    16571    cart 
   TABLE DATA           a   COPY public.cart (id, quantity, session_key, created_timestamp, product_id, user_id) FROM stdin;
    public               postgres    false    242   ?      {          0    16397    category 
   TABLE DATA           ;   COPY public.category (id, category_name, slug) FROM stdin;
    public               postgres    false    220   �      �          0    16550    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public               postgres    false    240   N                0    16427    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public               postgres    false    224         y          0    16389    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public               postgres    false    218   �      �          0    16673    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public               postgres    false    249   �      �          0    16503    employee 
   TABLE DATA           <   COPY public.employee (id, category_id, user_id) FROM stdin;
    public               postgres    false    238   ;      �          0    16590    order 
   TABLE DATA           �   COPY public."order" (id, created_timestamp, phone_number, requires_delivery, delivery_address, payment_on_get, comment, is_paid, status_id, user_id, delivery_date, delivery_time, order_finished_datetime) FROM stdin;
    public               postgres    false    244   j      �          0    16598 
   order_item 
   TABLE DATA           �   COPY public.order_item (id, name, price, quantity, created_timestamp, order_id, product_id, status_id, employee_id, work_ended_datetime) FROM stdin;
    public               postgres    false    246   �      �          0    16623    status 
   TABLE DATA           V   COPY public.status (id, status_name, status_description, status_category) FROM stdin;
    public               postgres    false    248   �!      �          0    16481    users 
   TABLE DATA           �   COPY public.users (id, password, last_login, is_superuser, username, first_name, last_name, email, is_staff, is_active, date_joined, image) FROM stdin;
    public               postgres    false    232   �"      �          0    16491    users_groups 
   TABLE DATA           =   COPY public.users_groups (id, user_id, group_id) FROM stdin;
    public               postgres    false    234   �$      �          0    16497    users_user_permissions 
   TABLE DATA           L   COPY public.users_user_permissions (id, user_id, permission_id) FROM stdin;
    public               postgres    false    236   �$      �           0    0    Service_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public."Service_id_seq"', 50, true);
          public               postgres    false    221            �           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public               postgres    false    227            �           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public               postgres    false    229            �           0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 52, true);
          public               postgres    false    225            �           0    0    cart_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.cart_id_seq', 73, true);
          public               postgres    false    241            �           0    0    django_admin_log_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 131, true);
          public               postgres    false    239            �           0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 14, true);
          public               postgres    false    223            �           0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 39, true);
          public               postgres    false    217            �           0    0    employee_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.employee_id_seq', 3, true);
          public               postgres    false    237            �           0    0    goods_category_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.goods_category_id_seq', 14, true);
          public               postgres    false    219            �           0    0    order_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.order_id_seq', 30, true);
          public               postgres    false    243            �           0    0    order_item_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.order_item_id_seq', 48, true);
          public               postgres    false    245            �           0    0    status_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.status_id_seq', 6, true);
          public               postgres    false    247            �           0    0    users_groups_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.users_groups_id_seq', 1, false);
          public               postgres    false    233            �           0    0    users_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.users_id_seq', 4, true);
          public               postgres    false    231            �           0    0    users_user_permissions_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.users_user_permissions_id_seq', 1, true);
          public               postgres    false    235            �           2606    16415    Service Service_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_pkey" PRIMARY KEY (id);
 B   ALTER TABLE ONLY public."Service" DROP CONSTRAINT "Service_pkey";
       public                 postgres    false    222            �           2606    16417    Service Service_slug_key 
   CONSTRAINT     W   ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_slug_key" UNIQUE (slug);
 F   ALTER TABLE ONLY public."Service" DROP CONSTRAINT "Service_slug_key";
       public                 postgres    false    222            �           2606    16478    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public                 postgres    false    228            �           2606    16464 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public                 postgres    false    230    230            �           2606    16453 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public                 postgres    false    230            �           2606    16445    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public                 postgres    false    228            �           2606    16455 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public                 postgres    false    226    226            �           2606    16439 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public                 postgres    false    226            �           2606    16576    cart cart_pkey 
   CONSTRAINT     L   ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_pkey PRIMARY KEY (id);
 8   ALTER TABLE ONLY public.cart DROP CONSTRAINT cart_pkey;
       public                 postgres    false    242            �           2606    16557 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public                 postgres    false    240            �           2606    16433 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public                 postgres    false    224    224            �           2606    16431 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public                 postgres    false    224            |           2606    16395 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public                 postgres    false    218            �           2606    16679 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public                 postgres    false    249            �           2606    16507    employee employee_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.employee DROP CONSTRAINT employee_pkey;
       public                 postgres    false    238                       2606    16403 )   category goods_category_category_name_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.category
    ADD CONSTRAINT goods_category_category_name_key UNIQUE (category_name);
 S   ALTER TABLE ONLY public.category DROP CONSTRAINT goods_category_category_name_key;
       public                 postgres    false    220            �           2606    16401    category goods_category_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.category
    ADD CONSTRAINT goods_category_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.category DROP CONSTRAINT goods_category_pkey;
       public                 postgres    false    220            �           2606    16405     category goods_category_slug_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.category
    ADD CONSTRAINT goods_category_slug_key UNIQUE (slug);
 J   ALTER TABLE ONLY public.category DROP CONSTRAINT goods_category_slug_key;
       public                 postgres    false    220            �           2606    16603    order_item order_item_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.order_item DROP CONSTRAINT order_item_pkey;
       public                 postgres    false    246            �           2606    16596    order order_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public."order" DROP CONSTRAINT order_pkey;
       public                 postgres    false    244            �           2606    16627    status status_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.status
    ADD CONSTRAINT status_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.status DROP CONSTRAINT status_pkey;
       public                 postgres    false    248            �           2606    16495    users_groups users_groups_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.users_groups DROP CONSTRAINT users_groups_pkey;
       public                 postgres    false    234            �           2606    16510 8   users_groups users_groups_user_id_group_id_fc7788e8_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_user_id_group_id_fc7788e8_uniq UNIQUE (user_id, group_id);
 b   ALTER TABLE ONLY public.users_groups DROP CONSTRAINT users_groups_user_id_group_id_fc7788e8_uniq;
       public                 postgres    false    234    234            �           2606    16487    users users_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
       public                 postgres    false    232            �           2606    16501 2   users_user_permissions users_user_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.users_user_permissions DROP CONSTRAINT users_user_permissions_pkey;
       public                 postgres    false    236            �           2606    16524 Q   users_user_permissions users_user_permissions_user_id_permission_id_3b86cbdf_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissions_user_id_permission_id_3b86cbdf_uniq UNIQUE (user_id, permission_id);
 {   ALTER TABLE ONLY public.users_user_permissions DROP CONSTRAINT users_user_permissions_user_id_permission_id_3b86cbdf_uniq;
       public                 postgres    false    236    236            �           2606    16489    users users_username_key 
   CONSTRAINT     W   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);
 B   ALTER TABLE ONLY public.users DROP CONSTRAINT users_username_key;
       public                 postgres    false    232            �           1259    16424    Service_category_id_fcdfa058    INDEX     [   CREATE INDEX "Service_category_id_fcdfa058" ON public."Service" USING btree (category_id);
 2   DROP INDEX public."Service_category_id_fcdfa058";
       public                 postgres    false    222            �           1259    16423    Service_slug_cab46943_like    INDEX     f   CREATE INDEX "Service_slug_cab46943_like" ON public."Service" USING btree (slug varchar_pattern_ops);
 0   DROP INDEX public."Service_slug_cab46943_like";
       public                 postgres    false    222            �           1259    16479    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public                 postgres    false    228            �           1259    16475 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public                 postgres    false    230            �           1259    16476 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public                 postgres    false    230            �           1259    16461 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public                 postgres    false    226            �           1259    16587    cart_product_id_508e72da    INDEX     O   CREATE INDEX cart_product_id_508e72da ON public.cart USING btree (product_id);
 ,   DROP INDEX public.cart_product_id_508e72da;
       public                 postgres    false    242            �           1259    16588    cart_user_id_1361a739    INDEX     I   CREATE INDEX cart_user_id_1361a739 ON public.cart USING btree (user_id);
 )   DROP INDEX public.cart_user_id_1361a739;
       public                 postgres    false    242            �           1259    16568 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public                 postgres    false    240            �           1259    16569 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public                 postgres    false    240            �           1259    16681 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public                 postgres    false    249            �           1259    16680 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public                 postgres    false    249            �           1259    16547    employee_category_id_9af3e737    INDEX     Y   CREATE INDEX employee_category_id_9af3e737 ON public.employee USING btree (category_id);
 1   DROP INDEX public.employee_category_id_9af3e737;
       public                 postgres    false    238            �           1259    16548    employee_user_id_cc4f5a1c    INDEX     Q   CREATE INDEX employee_user_id_cc4f5a1c ON public.employee USING btree (user_id);
 -   DROP INDEX public.employee_user_id_cc4f5a1c;
       public                 postgres    false    238            }           1259    16406 *   goods_category_category_name_7b12da53_like    INDEX     |   CREATE INDEX goods_category_category_name_7b12da53_like ON public.category USING btree (category_name varchar_pattern_ops);
 >   DROP INDEX public.goods_category_category_name_7b12da53_like;
       public                 postgres    false    220            �           1259    16407 !   goods_category_slug_370bc312_like    INDEX     j   CREATE INDEX goods_category_slug_370bc312_like ON public.category USING btree (slug varchar_pattern_ops);
 5   DROP INDEX public.goods_category_slug_370bc312_like;
       public                 postgres    false    220            �           1259    16652    order_item_employee_id_193da51a    INDEX     ]   CREATE INDEX order_item_employee_id_193da51a ON public.order_item USING btree (employee_id);
 3   DROP INDEX public.order_item_employee_id_193da51a;
       public                 postgres    false    246            �           1259    16620    order_item_order_id_0ca9e92e    INDEX     W   CREATE INDEX order_item_order_id_0ca9e92e ON public.order_item USING btree (order_id);
 0   DROP INDEX public.order_item_order_id_0ca9e92e;
       public                 postgres    false    246            �           1259    16621    order_item_product_id_62a1cc4c    INDEX     [   CREATE INDEX order_item_product_id_62a1cc4c ON public.order_item USING btree (product_id);
 2   DROP INDEX public.order_item_product_id_62a1cc4c;
       public                 postgres    false    246            �           1259    16646    order_item_status_id_755fd168    INDEX     Y   CREATE INDEX order_item_status_id_755fd168 ON public.order_item USING btree (status_id);
 1   DROP INDEX public.order_item_status_id_755fd168;
       public                 postgres    false    246            �           1259    16640    order_status_id_cd54252a    INDEX     Q   CREATE INDEX order_status_id_cd54252a ON public."order" USING btree (status_id);
 ,   DROP INDEX public.order_status_id_cd54252a;
       public                 postgres    false    244            �           1259    16609    order_user_id_e323497c    INDEX     M   CREATE INDEX order_user_id_e323497c ON public."order" USING btree (user_id);
 *   DROP INDEX public.order_user_id_e323497c;
       public                 postgres    false    244            �           1259    16522    users_groups_group_id_2f3517aa    INDEX     [   CREATE INDEX users_groups_group_id_2f3517aa ON public.users_groups USING btree (group_id);
 2   DROP INDEX public.users_groups_group_id_2f3517aa;
       public                 postgres    false    234            �           1259    16521    users_groups_user_id_f500bee5    INDEX     Y   CREATE INDEX users_groups_user_id_f500bee5 ON public.users_groups USING btree (user_id);
 1   DROP INDEX public.users_groups_user_id_f500bee5;
       public                 postgres    false    234            �           1259    16536 -   users_user_permissions_permission_id_6d08dcd2    INDEX     y   CREATE INDEX users_user_permissions_permission_id_6d08dcd2 ON public.users_user_permissions USING btree (permission_id);
 A   DROP INDEX public.users_user_permissions_permission_id_6d08dcd2;
       public                 postgres    false    236            �           1259    16535 '   users_user_permissions_user_id_92473840    INDEX     m   CREATE INDEX users_user_permissions_user_id_92473840 ON public.users_user_permissions USING btree (user_id);
 ;   DROP INDEX public.users_user_permissions_user_id_92473840;
       public                 postgres    false    236            �           1259    16508    users_username_e8658fc8_like    INDEX     f   CREATE INDEX users_username_e8658fc8_like ON public.users USING btree (username varchar_pattern_ops);
 0   DROP INDEX public.users_username_e8658fc8_like;
       public                 postgres    false    232            �           2620    16703 *   order_item check_employee_category_trigger    TRIGGER     �   CREATE TRIGGER check_employee_category_trigger BEFORE INSERT OR UPDATE ON public.order_item FOR EACH ROW WHEN ((new.employee_id IS NOT NULL)) EXECUTE FUNCTION public.check_employee_service_category();
 C   DROP TRIGGER check_employee_category_trigger ON public.order_item;
       public               postgres    false    252    246    246            �           2620    16701 6   order_item trigger_check_employee_before_status_change    TRIGGER     �   CREATE TRIGGER trigger_check_employee_before_status_change BEFORE UPDATE ON public.order_item FOR EACH ROW WHEN ((new.status_id IS DISTINCT FROM old.status_id)) EXECUTE FUNCTION public.check_employee_before_status_change();
 O   DROP TRIGGER trigger_check_employee_before_status_change ON public.order_item;
       public               postgres    false    246    268    246            �           2620    16698 2   order_item trigger_insert_update_order_item_status    TRIGGER     �   CREATE TRIGGER trigger_insert_update_order_item_status AFTER INSERT ON public.order_item FOR EACH ROW EXECUTE FUNCTION public.update_order_item_status_to_in_progress();
 K   DROP TRIGGER trigger_insert_update_order_item_status ON public.order_item;
       public               postgres    false    246    267            �           2620    16697 +   order_item trigger_update_order_item_status    TRIGGER     �   CREATE TRIGGER trigger_update_order_item_status AFTER UPDATE ON public.order_item FOR EACH ROW WHEN ((new.employee_id IS DISTINCT FROM old.employee_id)) EXECUTE FUNCTION public.update_order_item_status_to_in_progress();
 D   DROP TRIGGER trigger_update_order_item_status ON public.order_item;
       public               postgres    false    246    246    267            �           2620    16699 &   order_item trigger_update_order_status    TRIGGER     �   CREATE TRIGGER trigger_update_order_status AFTER UPDATE ON public.order_item FOR EACH ROW WHEN ((new.status_id IS DISTINCT FROM old.status_id)) EXECUTE FUNCTION public.update_order_status_based_on_items();
 ?   DROP TRIGGER trigger_update_order_status ON public.order_item;
       public               postgres    false    246    266    246            �           2620    16686 (   order_item update_order_item_status_time    TRIGGER     �   CREATE TRIGGER update_order_item_status_time BEFORE UPDATE ON public.order_item FOR EACH ROW EXECUTE FUNCTION public.update_order_item_status_and_time();
 A   DROP TRIGGER update_order_item_status_time ON public.order_item;
       public               postgres    false    250    246            �           2620    16687    order update_order_status_time    TRIGGER     �   CREATE TRIGGER update_order_status_time BEFORE UPDATE ON public."order" FOR EACH ROW EXECUTE FUNCTION public.update_order_status_and_time();
 9   DROP TRIGGER update_order_status_time ON public."order";
       public               postgres    false    251    244            �           2606    16418 3   Service Service_category_id_fcdfa058_fk_category_id    FK CONSTRAINT     �   ALTER TABLE ONLY public."Service"
    ADD CONSTRAINT "Service_category_id_fcdfa058_fk_category_id" FOREIGN KEY (category_id) REFERENCES public.category(id) DEFERRABLE INITIALLY DEFERRED;
 a   ALTER TABLE ONLY public."Service" DROP CONSTRAINT "Service_category_id_fcdfa058_fk_category_id";
       public               postgres    false    220    222    4737            �           2606    16470 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public               postgres    false    230    4755    226            �           2606    16465 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public               postgres    false    228    230    4760            �           2606    16456 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public               postgres    false    226    4750    224            �           2606    16577 +   cart cart_product_id_508e72da_fk_Service_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.cart
    ADD CONSTRAINT "cart_product_id_508e72da_fk_Service_id" FOREIGN KEY (product_id) REFERENCES public."Service"(id) DEFERRABLE INITIALLY DEFERRED;
 W   ALTER TABLE ONLY public.cart DROP CONSTRAINT "cart_product_id_508e72da_fk_Service_id";
       public               postgres    false    242    222    4743            �           2606    16582 &   cart cart_user_id_1361a739_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_user_id_1361a739_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 P   ALTER TABLE ONLY public.cart DROP CONSTRAINT cart_user_id_1361a739_fk_users_id;
       public               postgres    false    242    232    4768            �           2606    16558 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public               postgres    false    224    240    4750            �           2606    16563 >   django_admin_log django_admin_log_user_id_c564eba6_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_id;
       public               postgres    false    4768    232    240            �           2606    16537 5   employee employee_category_id_9af3e737_fk_category_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_category_id_9af3e737_fk_category_id FOREIGN KEY (category_id) REFERENCES public.category(id) DEFERRABLE INITIALLY DEFERRED;
 _   ALTER TABLE ONLY public.employee DROP CONSTRAINT employee_category_id_9af3e737_fk_category_id;
       public               postgres    false    220    238    4737            �           2606    16542 .   employee employee_user_id_cc4f5a1c_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.employee
    ADD CONSTRAINT employee_user_id_cc4f5a1c_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 X   ALTER TABLE ONLY public.employee DROP CONSTRAINT employee_user_id_cc4f5a1c_fk_users_id;
       public               postgres    false    4768    238    232            �           2606    16663 9   order_item order_item_employee_id_193da51a_fk_employee_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_employee_id_193da51a_fk_employee_id FOREIGN KEY (employee_id) REFERENCES public.employee(id) DEFERRABLE INITIALLY DEFERRED;
 c   ALTER TABLE ONLY public.order_item DROP CONSTRAINT order_item_employee_id_193da51a_fk_employee_id;
       public               postgres    false    238    4786    246            �           2606    16610 3   order_item order_item_order_id_0ca9e92e_fk_order_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_order_id_0ca9e92e_fk_order_id FOREIGN KEY (order_id) REFERENCES public."order"(id) DEFERRABLE INITIALLY DEFERRED;
 ]   ALTER TABLE ONLY public.order_item DROP CONSTRAINT order_item_order_id_0ca9e92e_fk_order_id;
       public               postgres    false    246    244    4797            �           2606    16615 7   order_item order_item_product_id_62a1cc4c_fk_Service_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT "order_item_product_id_62a1cc4c_fk_Service_id" FOREIGN KEY (product_id) REFERENCES public."Service"(id) DEFERRABLE INITIALLY DEFERRED;
 c   ALTER TABLE ONLY public.order_item DROP CONSTRAINT "order_item_product_id_62a1cc4c_fk_Service_id";
       public               postgres    false    222    246    4743            �           2606    16691 5   order_item order_item_status_id_755fd168_fk_status_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_status_id_755fd168_fk_status_id FOREIGN KEY (status_id) REFERENCES public.status(id) DEFERRABLE INITIALLY DEFERRED;
 _   ALTER TABLE ONLY public.order_item DROP CONSTRAINT order_item_status_id_755fd168_fk_status_id;
       public               postgres    false    4807    246    248            �           2606    16653 +   order order_status_id_cd54252a_fk_status_id    FK CONSTRAINT     �   ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_status_id_cd54252a_fk_status_id FOREIGN KEY (status_id) REFERENCES public.status(id) DEFERRABLE INITIALLY DEFERRED;
 W   ALTER TABLE ONLY public."order" DROP CONSTRAINT order_status_id_cd54252a_fk_status_id;
       public               postgres    false    244    248    4807            �           2606    16604 (   order order_user_id_e323497c_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_user_id_e323497c_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 T   ALTER TABLE ONLY public."order" DROP CONSTRAINT order_user_id_e323497c_fk_users_id;
       public               postgres    false    232    244    4768            �           2606    16516 <   users_groups users_groups_group_id_2f3517aa_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_group_id_2f3517aa_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 f   ALTER TABLE ONLY public.users_groups DROP CONSTRAINT users_groups_group_id_2f3517aa_fk_auth_group_id;
       public               postgres    false    234    4760    228            �           2606    16511 6   users_groups users_groups_user_id_f500bee5_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_groups
    ADD CONSTRAINT users_groups_user_id_f500bee5_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 `   ALTER TABLE ONLY public.users_groups DROP CONSTRAINT users_groups_user_id_f500bee5_fk_users_id;
       public               postgres    false    234    232    4768            �           2606    16530 O   users_user_permissions users_user_permissio_permission_id_6d08dcd2_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissio_permission_id_6d08dcd2_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.users_user_permissions DROP CONSTRAINT users_user_permissio_permission_id_6d08dcd2_fk_auth_perm;
       public               postgres    false    4755    236    226            �           2606    16525 J   users_user_permissions users_user_permissions_user_id_92473840_fk_users_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_user_permissions
    ADD CONSTRAINT users_user_permissions_user_id_92473840_fk_users_id FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.users_user_permissions DROP CONSTRAINT users_user_permissions_user_id_92473840_fk_users_id;
       public               postgres    false    4768    236    232            }   Q  x��X[s�F~���.��14n]_�LH��#�5Z�	l�ۓ�3i������@L��o��Գ�0���l�FZ�Ξ����sVQ���!��czM���޸�������l�ӌ�3��g�	� \_c:����:��\n5���L9k��A��E:��.�#���&�e5�!���<b�͝�Mc�Qg�����Q�`{HG��M�xK���a�pߧ������#܌�M`����/ Q�ZXn�Ĳ�&g[}ܖm�;rBi�AlҬ�*�تs8y��P
��\|��Ld$c�����cp4yup���Ԓ1��VEG�J����U|n����t��u�����=����0<�C!�T��;V֒�ɶ,�.
U�O��H�'�h͉P{4����tY�����Lgf���0ݏMִ��N �����rKP��ڨ+s���@��uY�ݓEF���2b0���&g?�<N���;�5۱	�,m�2���M{��dj�F#ql�&�:
��혅���};�+�>� ��{��1��X�f��=C��wPi��ST&s� [̷���[��U
n$s�mh�]��g���*L�<0-y!������j��RS}L+/8xÂ���qpb�U��,�=1H#:���,p��KUi��o%A�^/�-�F��
 ���h$al��Ϥ�Oy��ɣ��3W��k�� ]!�<���}��Kp�_�y(Xl
D�!/_$�Dg��&AY�&VTdipC�,�7Pq_61�|�c�~���R��|9������[�߲����pZD>�Z���R���
�ǥd�7�G*���kJ.�����3N��\M"H����h�����=h����SÉDk���6�e�r�Zw��U�J!Bq�2\��������KQeH7��@RF}޸�΃Ε{��f��i%\�ȺG��,3���Y��凁�u�I�$۳�p,���neL4�J����k����<}��Y;��Lu����FQWk�����GL�J���Y�Z�P�^y�`n���ka�F��6V�k�<���EQ�_�x��S��4R4���s�[��0�j�G�P���fy&M�:,�<t1��٦O� $������n����R�鰧���^Z�����W�Z�}./IAw�������ИaJ�M�I��^V�Y��i:�
5:�D��T�<��"k�}_T+i�q2�Y�˪E�y�P�x�9�$�t�)Rv�/Q���&�ᢐ����ӗ?(� Vx�ɋ��P��$���^N7�s(�}o䌞��(�@G��)����F�>���&+�#���Z���^+��5}߯����)��      �      x������ � �      �      x������ � �      �   v  x�}�Mn�0F��)|�����u��l�`K�$��.��A�,�M�F��A�ԍJ�#r��lQo�7c~r�>��,_�g�j3e[Y���u�oy���׼�B�%F\��h)h�k���/8(�f{Q)���Z�-��# �!6�~�A�fN���qKk���ÞEZP������ ;� :���8���l��f�q/X�E`�_�A�u<��`7�E�/��Gk_¦ֺf���;dX�1�i�%vt�X8wj�V	���)�ݽ�'_�Gw'_�G�0��[���H�L���@m	I�h�0S[�r2Z`�jq����.߻�|�N,��ַ�J�$��t�%��X;b`Qb<��K��%?� /�����=�LT	�H�&*@��TMA��l�D7c
\���U�;��_y���-ub��VG!xD�7�C���o��]	��h��wx��|�.���3S�.s��G�w�=О��]z��c�Wl<'��#�l�J�y�o꺰��KU�Z�1�#�@@�B��8{�b %#f��MtO��4��)t�E+v<^�KOl�{1{���L��4{dc�N��&`�Q��URTZ�
��¦��C�d^<���z�����#͋�p7�8���v�s      �   S   x�u̱� F�:���#G~��	��Z��|�"Iiބ
+�R� �c4�!�Z8�?�4����Oj���^�.:��l��      {   �   x�e�M
�@���)<���i��E�)#���<�7����V�^nd�R!��}y�Y�#)t�R���"�x�	Zt�x�}��q>��f�3B�
thPINi�xe<'\�
h$����Ō36���^h\�:?Ʒz9t���:'u����̯c�x5f�6��      �   �  x���n��<���� 	bU�ի�Ͼ�lh��/	� ǀ$�v �Q`�)q���Zl��_���|Iޫ�&��{�r8gI3�V�[�U6��T��[�`*e+�0��G~4��������������ɫɳ駓��G�#~pDo�O��w��8�|5y��'ߏ�����A���o����{�8ؿY�?�y���w�?��o�|���K� �h_P�?iL/0�?����~������8��ѥ�졮��g�l��l)2�Mg����W��[}���H�pX�e�Ax���RV�@p:WB�*����0x��Ί��	�#�������)�����KzsL��%,L?�~B?��=���޻�������Gu��+���Kf�������ߝL���޸M	<ls��mnC�C1�>�稹��X^���� ,��)�e�B���z�Yf��o�Fи��e녿��^��&�*V��dQ��o֤ix��A�� iv ��!��lT��.@Skv���f{5�<�C���z;�T�x�	�Aƀsk}�,��0�))TZAB�#��#��|�?{����c��v)ܱ6zd�P0(�JA��W�9T��D���b���q��d�ߙ��1��J��%h�Ғ@3���|G���� �QmQ/�D��
�<h��
�}��c��阁#@�Ϣ�u��ֿ���9b�+�.��J	R���8�A���Сp�b��*C/,y��K�p�؄�&X�Br�URd� ����1�+�.ˇ�Y~�=	Gizh_%�Đ�e)ў�V�8l㾱$���f��lmf��{��̿�7Z��X�ͨ�IL�	fN�Lh�.�dn��
��^��FG�I=����������ӮH�Aﲢ��OR|��� m�3\�� 3t�39�����§�N߸g�q�`4�cwp2��sN��<����9��E�Q�M��j�eK�t%��dF����J�U���|��f��T��=z�2����zBy�D-�1�9T�La4��~�L��O6�gc��3�EƄ�o�����;���W��%�d�z��?v� 6�RF6�QA��atw�	(S����,��j����X<�L1hWbgl���h[L+��)|4y>cXW�"!��K"�%m�!Tu��^���� -C&�O��M��*�SAA� j�O�O�;���Yk\�9l�;cv(gW*��S�a�$;�h���3�rFd���S�h���UN:H6��؝ؠPC�3��/i�����y8��Y��	��M�ڤ|�]��r���%X�+�2.�^�yQ��LS+m!,ܐi#E��
�@C�H�H��a��C#اjI!��9"�����h	�W ga����pr۸1 �o���-�u�Ӵ!8�W	]=��NO���!)g}��4셞�;h���,���ͽ�,]�r��'�N�m`��,9K[4�,��5	�$|��k����@(6z��I���,��Hl�ƍ���EY��H� �W�bq���i��)�J�Z�HӦ����s0�5��<d�/jGF����W�߰�I��=0�h�M�'�FDM���ζ�UnL4��Q�)P=÷��=p��p�(��8E�n|����\^z�bm"@U�I�'Ȇ�d����B���4�uF(-����]��� �x��(,wEc+m�
��#G��f{)�$\F�h2b�� [������ja�.l\� �a��d�%�/H�[m��M�5NS�B&+E��m�Z-*�cZP۾�`�"���
,/�q&[����|@M�
�pB	�Cۓ䲯_�	�z�&��|��ǝ��������rC�N�QX�lr�9��z���,G�x(9�� ̒���B��a9 ��Vam����|��n�}�,JC��WH�28iw������`$J��\Mn�]6�������E�����rѪ���J�س�vDM>�@�MA�hQۊu;�z�C�^{�~�X�f�9���V�b=��$W��4�#�N�6,c��қW\���uO�����#���D�c�����8�1rB�_	e5J�����B͡dل�1L~�_���8��O��>ݱl���ۅ2�$B{g��]��LV�^p�H]��:��M��|u"��e�0Z�Q��sQKb˼��τ�vh孳�p�i��}b��MO�<ܛޝ>������ ��2��6ִ���
=Gϱn$���2ڢ�hK���p���]N/���] ˬW�֎�� �;��I�x�eL��l/$���.M��*�6�)O˙bn�URsׄ�];�t���������g�&�Y��5`�PK��T��0x�����,N-�cs.PI����ݘ���.C��+a$y�MqY�8^��X��s�������}�;�"�|Q�`�����F��x����p����U؃� �T�&��`Kw�Ve��Ҿ=�2]liM��sj����A�=E���mJ�^b�[�Q��q8��]w,��V� ���of�Ž��5�[���t���d�`�ڭ�mh� �n���׵���?�V�E3��p��h��pР:�j�74U�f9A��4��������A�$����g�V5��{�ɽf�*��.A�CA���֤`L2�0H�7�*� Es���H�6�|\]��J�]�j75�  [*�,��A(�<>|��î�bA�� '��lZ��za�����&�����N��m������v���������ٝx^�y,��Hr%l
��{i��H�ꁋm�RP���M��ܐ�*�9$��YcT�h�+���oj�Ng� ��dG�.��6�d,�f��a���h�,����6�Y��C��׶��h�n)�(��})b{�r�b��h�ʀ͹�WX����l=�e��F�!��P��B���j�uATNh��y��k�w��<\���p��J���y�W$Kz����f�x:��p��
+�pl5�
��6��"�2�2[ǝ/���5�*���b�d�!��<�N�t��늻2f6�P�R Vj���e���R�:�S���r�ޏf�yM-e�)�S�%xHU"W�����a;N�Ö́�P8a�º��:7|���S�J�X����^X���-� ˎa>�T���7S��.~#S��r�����i��ު{��I�݊[m��eN6�� ��<��A��q;�g��q�T��-�y\*qd�����&.u�}kz��+� R?�����މ�Hң�bG.�?�{��\W����$�?���>^u�`�$���'/�N�5?Ă�G���g��t�K=��#�4;Z�J���7�nQ�<h;nj>�Z�ƌ��(�X��7�,Gn��"�	?����9�NsOO@PN5��K\!�Lӹ4��t��6C���P<�@���te���g�����e����`����usѹ���vtN{��R�A*g���&��;�R�G�3TO�1���������<6��[Y7I;��nD8��=ԃ���qP�4Շ�y.��2�;7 n��|�e2L�P���;���$�����3,���� "3Ĕ�p�Q����;�w�j�����ƓS����u��!�M.t��0;��+e�~Aئ��.���㗋��h�hc��v̵�̵�S+w,��,�����a�V�����J�
Ȟ�h��8��Wke(-?!�Pr�����]�q��\Iʺ]�ɢ�q���;�3         �   x�U��
�0���Ì����Z�����o�,ka����dG~L1�$����Ş4sIQ5JF�MB�eƉ�V��ά��3)���
"c�y� ��u��+�-�jS�7�4O�2�벘6�s$e�ځ��8'�~�Լ-����4MD      y     x����r� E���{'�Kgj��$\����@F�#9�K�A��>[���\�W  �lg��M� "/� ��#EG_!D��� �,AJ7�xu�������6fCO ���z��w�`]�?.�:���Z��o�(@�6dކL����=��K��V��p�S�G�7���}�?�a� qlƱ"�mrC6��1j����|(x�+�L���u�t!�.fO$��J�I��G�����m��	A���cw�)M���H�ھ�E�ȴ�C5�;�o��(%4�Pa��9D�i�m��p�3Yb�?�@�#�`r�$�A��F�A5�lcmC�a��e?i��ؓ߃��)�[j�m��	�
䞸�nl���1ku���Ϋ��}��Fe��`�N���Ϝ���$?y�%��%�(&�ٻ�C$i:��B��K�Ȩ�w�E&7�B��(��hY՛�{˒�˔D��Q��uF�V���bz��v;4H���"2k�Ϙ�8��)�qcN�!q*�!:C��O�So�>�ӻ�Sm�E�#�EV��{*'�M��Y3_n><���B:�-��,�c�8}D&���z_�8�0����L޴�j�ث�&�I�]]~�"�	O�b���>�0�h�i���O^Z�b �L}�h�%�i/����sa�@�ㅜ�l�\���B���mR>=xV4��S���۵?��R��M=��i�0��Wl�w����u���C�1�Y��|�aQ�f��_�FX6j�N���tkv���+����ʏ�����_"u      �   r  x���ٲ�H���s���wh� I&w(�8!N���̃Oߺ�TuU��'�#?ȵ���* �x5W�q4vh�c!�e`�ꇇ���VbQ=�$|2�dn����+W���,����=L������ �&L0������bD	��?iD¼L��:�0�(�n�
�q
{�z��Qݗ�h1���ښ9�����iu����a���|�<������E̋�Ld��DØ�B�Z�,{B�ībd�Xڎ���g����c9_(�������^[Dm��&�������%"ঐ���S��:R=�5`�	��\��j@�ܵ~W� �_']�	D>Ҿ����l5c3�6Dq�G���R�4W��_��H�b3F��
�AG�ZY��V���'��C�cꭇk���>���?Y4'�-=8mKq�T�b�6�L��UH���曙�`5�y�v��3�0X�U:�D�M�S9�ǣ�T�������;����EOw�ҵ�-��"���p�@{ڋk�H����ȫ1�&��H"��DM�v^.��@NY[i���`55��D�2;>��SV���+"E�OyF!�"z�{�C��p�
W��c���O~�o�X�g�#Z�y`ưМ��5m7����Z���#�J�6B��)�}�ڪoG#	����w�HK����.�\Yh��rdl��h�$�L��lhaT��9�C��ay�JR��;%��<�9ǻ��)�;y�r��M�}�*��V�*p�y�ք�v��/	�^��(�2L%���P��)��ѯ×U�� �ՎiG+����xd�ߒ�2��z�����2��j��H���>TٵR��a���_��_���{�	SN��>D�X������8\eN�R�����|G"%[j";d��su���{�c���*R�E��_��-V�y����=D�����ue�8��,� &e��!-��!�e��VQP��Umlu�\��X�q�嗆9?g`n��Õ��n{��A���B�l�0!�¶�QU'�R.ʲ��;;�R0R8�7���w\{�9
��en����<�V���ݶi���b�=:`(�	��R"�x]�V�]��ѿ�L��|�i�ek�)ye���}����ͣ���ŕ+��d΃�P��C���@o+�7Z�&�^^�ػDS�u���~6�*�z�g;���%���Yp�O!���������I�+��j��D�������k��=W�K��Ňq���
������'�}}KUt=��pU�9�}�MO�A���ޯ�Lm��0G�oD�w!�2� �>DN	j��<�J�q���ܱG�s���I�gbM/2i^n7����c�f�1+�j�&�au���l��M�]�A���,��E���ϟ?���t�      �      x�3�4�4�2�4�4�2�4�4����� !��      �   '  x��UKn�0]˧о5�r��!z/;�us�&.��}� �� I�8N�@ݨ���i
ɐLR�33䄂5�!�!sɺ��2�ز��J�"�h��.�EqT��z���2=��^/�U}R��i���ó>�O�v�����CTWZ��Ā�vƔ���B�~P.�M�9��t�O��97�H%��t�(b-�9_kt���./����+�V�Ў�6.�,�!ݧ9�hW��:�F�t�I%�R�=!��)���h\O@��1�2:�6{� .����/0v��R���EI(�բ{\Wi�����/���A���dwfJ��Z;�t���9A��^׼��u� ���6��Lӗ�~U���tզ}��$_�؏Tl�{�$6�B����r6��t��@�q�oe�iG��wY���Y_�t�%�fh�CIT�P�QV;!�kxގ�Ӑ\&�$�u���U�J4y��D�!jgMk�	<��!�A�����.��+ަhy]�<Ԅm�CFNg%���U`�5;=�MX��X�2��*���]p�̠u�	ieN�Ӄɣ��$���VY�QL���X������8N���bw���֫����*�$ra��䏜��i�	tb�)�Z���~�p@��ۜ���R	)���_\��n��w)-� ��3�۸��F�E<��i��<d7 �	��A���ʈ�=�Y,s#n@;�c4t6�F�tT}�a]4dC`�G�9N�{����"]�a_7M��'��^ g��g��9
�C���r�w{��>z�(GA俦��t3���!���`���_j2�      �   �  x��WK��F]���ޘF׷�y�����8H��"� YIn��V"����7Ju�ԇE�@�h 	������c��̻�%?���M~�[�����?7��=����hǱ#qJ^|z�Ɏ5�-�	u����k�ɿ��k�n����W���ׇ���? m�w���J��4�v��w��r����6��+�������w�v�����>|����}�`qؑ�keI
�c�0:@�	*�o��T�V����z�?���H�%s��ɠ�����at�X�(/�
C'�GC%��p�p����2����GC��Q�=U8j0��u���_��B��:E�	��q��0�,�_�e���6����0��#<�GU���+�J�AU��z`��{��J*��!�M8c��Kp���G�Sq��{�^H&��{`�Ƶb���	�"����+���\�詪�+�oJQ�	1�)����n?��2ô@UT� TH�P���jG�����F4<�X $t>9DE�+�YE,��PR�|�J%f�Qq$6%��E�sb��2'�����T<:vP�k�9�I�(X�����B*4*M��T�u�� ��@�js�IuY��4�]F1�L��F����l�c�q�/mZ&=w�\2Wa��֤�k#��҆&�T6��o��A���� z�RE4h
u��xcN/T&�<�EY��;��'qtAHJ�N�����~������U?C�3��#e��b��d]�& ���%T�ᨍ�zq�Reҵ��%���R��%vH�T#`%���]���Uz�
l�s���W6������8�ܺò�C�xW����S���Tj�!�ag,�~�R�s�d@�m.��B,�V�^�T�凐����ub�A�&�T�M-U�o�;�J'��<̊���b������RH�x��n�\P�X�N'4�z�G� :VR����Z%I�7��MP+<��z�0�y�A�0E�le5`�e�ֵm��Ka      �   �   x�mPKN�0\ǧxK�AJK{�&�V
"��.��F͇+̻�$jm�<��{O	���4�=zt�9~0���n5�}�cB�ݬ�iy%�r��E��`�����&��p|Ҍ�'���v	��Zi.�v�I�0���c7%�&����@A��,ɓ����`먚V\@ΝT�)�5�֋L�a�st><OG�N�E�u�����R�����3��ks��u7����.q��Gc�/�;C      �     x�u��n�@���)X��p�_F�T�r���"!_c��R`WUUW��������h�Wިv�KёF::s��:�� D�Ҟ�i<70����S����pF�x�+#X�@#(��Ag�/d�r�bN��V;���.Ԋj5�>��J��	a��Z#
@�*b���0�a����?�-�I��;~��x氵������Og��bJ0%�J�HB�fj/b����o8��t���1q99I ẛ
�^2�����}`����Ey�)*�L;W:���ycbuǞ-'5��=�m
���N��h7�����.7v���[�z��|�ٗu�o��G��P�"BDQ�_�X�Zsg��f��������:�M[�;���R�-$��G�A�D�B�"JD��M�'㞃�g�ތ��վS5a?kZ����A��lt��/M�27���4K��\����*��W��$Z�D�4�H�s"�m�������}X���?Jc �A��DAM�I(�c �+L�S�	���0\��\�'����      �      x������ � �      �      x�3�4�4����� �]     