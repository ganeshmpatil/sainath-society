BEGIN;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-001', '42d71866-259a-4e81-8abd-3ec8df859893', 0, 500, 'Himani Hemchandra Patil')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Himani Hemchandra Patil', '1000000001', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'himani.patil@aangan.com', '1000000001', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-101', '42d71866-259a-4e81-8abd-3ec8df859893', 1, 500, 'Gajanan Vishnu Sulik')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Gajanan Vishnu Sulik', '1000000002', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'gajanan.sulik@aangan.com', '1000000002', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-102', '42d71866-259a-4e81-8abd-3ec8df859893', 1, 500, 'Pradeep Waman Chavhan')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Pradeep Waman Chavhan', '1000000003', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'pradeep.chavhan@aangan.com', '1000000003', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-103', '42d71866-259a-4e81-8abd-3ec8df859893', 1, 500, 'Chandrakant Sonu Salvi')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Chandrakant Sonu Salvi', '1000000004', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'chandrakant.salvi@aangan.com', '1000000004', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-201', '42d71866-259a-4e81-8abd-3ec8df859893', 2, 500, 'Pratibha Ravji Sawant')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Pratibha Ravji Sawant', '1000000005', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'pratibha.sawant@aangan.com', '1000000005', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-202', '42d71866-259a-4e81-8abd-3ec8df859893', 2, 500, 'Kattika Lakshmi R. Rao')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Kattika Lakshmi R. Rao', '9004000284', '', v_flat_id, 'ADMIN', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'kattika.rao@aangan.com', '9004000284', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-203', '42d71866-259a-4e81-8abd-3ec8df859893', 2, 500, 'Anupkumar S. Karkala')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Anupkumar S. Karkala', '1000000006', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'anupkumar.karkala@aangan.com', '1000000006', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-301', '42d71866-259a-4e81-8abd-3ec8df859893', 3, 500, 'Sharad Keshav Shirke')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sharad Keshav Shirke', '1000000007', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sharad.shirke@aangan.com', '1000000007', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-302', '42d71866-259a-4e81-8abd-3ec8df859893', 3, 500, 'Shrutika Sandip Rane')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Shrutika Sandip Rane', '1000000008', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'shrutika.rane@aangan.com', '1000000008', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-303', '42d71866-259a-4e81-8abd-3ec8df859893', 3, 500, 'Sopan Tukaram Bangar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sopan Tukaram Bangar', '1000000009', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sopan.bangar@aangan.com', '1000000009', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-401', '42d71866-259a-4e81-8abd-3ec8df859893', 4, 500, 'Baburao Madhav Kamat')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Baburao Madhav Kamat', '1000000010', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'baburao.kamat@aangan.com', '1000000010', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-402', '42d71866-259a-4e81-8abd-3ec8df859893', 4, 500, 'Sanhita Sanjiv Rane')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sanhita Sanjiv Rane', '1000000011', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sanhita.rane@aangan.com', '1000000011', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'A-403', '42d71866-259a-4e81-8abd-3ec8df859893', 4, 500, 'Shamrao Balku Supugade')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Shamrao Balku Supugade', '7678008004', '', v_flat_id, 'ADMIN', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'shamrao.supugade@aangan.com', '7678008004', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-101', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 1, 500, 'Nandraj Dattatray Khavale')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Nandraj Dattatray Khavale', '1000000012', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'nandraj.khavale@aangan.com', '1000000012', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-102', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 1, 500, 'Prachi Prafull Chavhan')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Prachi Prafull Chavhan', '1000000013', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'prachi.chavhan@aangan.com', '1000000013', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-103', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 1, 500, 'Kaushalyadevi Chhotelal Gupta')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Kaushalyadevi Chhotelal Gupta', '1000000014', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'kaushalyadevi.gupta@aangan.com', '1000000014', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-104', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 1, 500, 'Subhash Narayan Pawar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Subhash Narayan Pawar', '1000000015', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'subhash.pawar@aangan.com', '1000000015', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-201', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 2, 500, 'Sunita Suryakant Sawant')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sunita Suryakant Sawant', '1000000016', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sunita.sawant@aangan.com', '1000000016', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-202', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 2, 500, 'Shraddha Vijay Sawant')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Shraddha Vijay Sawant', '1000000017', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'shraddha.sawant@aangan.com', '1000000017', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-203', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 2, 500, 'Purushottam Lakshman Rane')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Purushottam Lakshman Rane', '1000000018', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'purushottam.rane@aangan.com', '1000000018', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-204', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 2, 500, 'Shobha Sakharam Hadbale')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Shobha Sakharam Hadbale', '1000000019', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'shobha.hadbale@aangan.com', '1000000019', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-301', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 3, 500, 'Sambhaji Sakharam Mali')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sambhaji Sakharam Mali', '1000000020', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sambhaji.mali@aangan.com', '1000000020', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-302', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 3, 500, 'Yogesh Balkrishna Gawde')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Yogesh Balkrishna Gawde', '1000000021', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'yogesh.gawde@aangan.com', '1000000021', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-303', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 3, 500, 'Snehalata Balkrishna Gawde')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Snehalata Balkrishna Gawde', '1000000022', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'snehalata.gawde@aangan.com', '1000000022', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-304', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 3, 500, 'Daji Kashiram Jadhav')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Daji Kashiram Jadhav', '1000000023', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'daji.jadhav@aangan.com', '1000000023', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-401', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 4, 500, 'Harji Ambavi Chaudhari')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Harji Ambavi Chaudhari', '1000000024', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'harji.chaudhari@aangan.com', '1000000024', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-402', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 4, 500, 'Sumant Mahadev Chindarkar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sumant Mahadev Chindarkar', '1000000025', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sumant.chindarkar@aangan.com', '1000000025', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-403', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 4, 500, 'Waman Lakshman Tribhuvan')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Waman Lakshman Tribhuvan', '1000000026', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'waman.tribhuvan@aangan.com', '1000000026', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'B-404', 'd194a7ce-d494-4473-ab3f-00ad04a58cd1', 4, 500, 'Suresh Babu Nikam')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Suresh Babu Nikam', '8369007188', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'suresh.nikam@aangan.com', '8369007188', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-101', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 1, 500, 'Jaydeep Anant Dalvi')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Jaydeep Anant Dalvi', '1000000027', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'jaydeep.dalvi@aangan.com', '1000000027', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-102', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 1, 500, 'Shashibhushan O. Sharma')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Shashibhushan O. Sharma', '1000000028', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'shashibhushan.sharma@aangan.com', '1000000028', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-103', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 1, 500, 'Bhau Ganpat Gawde')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Bhau Ganpat Gawde', '1000000029', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'bhau.gawde@aangan.com', '1000000029', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-104', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 1, 500, 'Juliana P. D''Lima')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Juliana P. D''Lima', '1000000030', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'juliana.dlima@aangan.com', '1000000030', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-201', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 2, 500, 'Krishna Keshav Shivalkar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Krishna Keshav Shivalkar', '1000000031', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'krishna.shivalkar@aangan.com', '1000000031', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-202', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 2, 500, 'Prabhatilal Jalimsingh Yadav')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Prabhatilal Jalimsingh Yadav', '1000000032', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'prabhatilal.yadav@aangan.com', '1000000032', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-203', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 2, 500, 'Sushiladevi Prabhatilal Yadav')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sushiladevi Prabhatilal Yadav', '1000000033', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sushiladevi.yadav@aangan.com', '1000000033', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-204', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 2, 500, 'Shukla Jaydev Das')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Shukla Jaydev Das', '1000000034', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'shukla.das@aangan.com', '1000000034', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-301', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 3, 500, 'Ravindranath Bapu Sawant')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Ravindranath Bapu Sawant', '1000000035', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'ravindranath.sawant@aangan.com', '1000000035', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-302', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 3, 500, 'Vasant Babu Sawant')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Vasant Babu Sawant', '1000000036', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'vasant.sawant@aangan.com', '1000000036', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-303', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 3, 500, 'Sujata Mahesh Rane')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sujata Mahesh Rane', '1000000037', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sujata.rane@aangan.com', '1000000037', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-304', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 3, 500, 'Shubhangi Jayram Wanjhe')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Shubhangi Jayram Wanjhe', '1000000038', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'shubhangi.wanjhe@aangan.com', '1000000038', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-401', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 4, 500, 'Sugandha Chandrakant Uparkar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sugandha Chandrakant Uparkar', '1000000039', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sugandha.uparkar@aangan.com', '1000000039', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-402', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 4, 500, 'Pravin Vinayak Kanade')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Pravin Vinayak Kanade', '9321053817', '', v_flat_id, 'ADMIN', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'pravin.kanade@aangan.com', '9321053817', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-403', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 4, 500, 'Ashok Tukaram Gurav')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Ashok Tukaram Gurav', '1000000040', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'ashok.gurav@aangan.com', '1000000040', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'C-404', '2e21f09f-6c23-49c8-8490-73745dd9acf8', 4, 500, 'Vinay Suresh Ayre')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Vinay Suresh Ayre', '9987203125', 'coolvinayaksawant@gmail.com', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'coolvinayaksawant@gmail.com', '9987203125', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-001', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 0, 500, 'Vinay Chandrakant Parab')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Vinay Chandrakant Parab', '1000000041', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'vinay.parab@aangan.com', '1000000041', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-101', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 1, 500, 'Mohini Prashant Kapdi')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Mohini Prashant Kapdi', '1000000042', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'mohini.kapdi@aangan.com', '1000000042', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-102', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 1, 500, 'Vishwanath R. Shetty')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Vishwanath R. Shetty', '9619865143', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'vishwanath.shetty@aangan.com', '9619865143', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-103', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 1, 500, 'Ranjanben V. Kapadiya')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Ranjanben V. Kapadiya', '1000000043', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'ranjanben.kapadiya@aangan.com', '1000000043', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-201', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 2, 500, 'Pramila V. Gawde')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Pramila V. Gawde', '1000000044', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'pramila.gawde@aangan.com', '1000000044', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-202', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 2, 500, 'Sukhdev Adikrao Jadhav')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sukhdev Adikrao Jadhav', '1000000045', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sukhdev.jadhav@aangan.com', '1000000045', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-203', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 2, 500, 'Manohar Vishnu Sadvekar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Manohar Vishnu Sadvekar', '1000000046', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'manohar.sadvekar@aangan.com', '1000000046', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-301', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 3, 500, 'Lalasaheb Vishnu Mahadik')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Lalasaheb Vishnu Mahadik', '1000000047', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'lalasaheb.mahadik@aangan.com', '1000000047', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-302', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 3, 500, 'Ranganath Bhausaheb Ambedkar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Ranganath Bhausaheb Ambedkar', '9920593086', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'ranganath.ambedkar@aangan.com', '9920593086', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-303', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 3, 500, 'Indu Hanumant Jagtap')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Indu Hanumant Jagtap', '1000000048', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'indu.jagtap@aangan.com', '1000000048', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-401', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 4, 500, 'Anjali Darshan Yeram')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Anjali Darshan Yeram', '1000000049', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'anjali.yeram@aangan.com', '1000000049', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-402', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 4, 500, 'Madhuri Krishna Morajkar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Madhuri Krishna Morajkar', '1000000050', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'madhuri.morajkar@aangan.com', '1000000050', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'D-403', '0b9b5480-b912-48f7-85f5-dfa829a151d7', 4, 500, 'Chandrakant Ravsaheb Gawde')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Chandrakant Ravsaheb Gawde', '1000000051', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'chandrakant.gawde@aangan.com', '1000000051', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-101', '3705ae4f-2fdc-493d-972d-c76865398002', 1, 500, 'Rasika Dilip Rajebhosale')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Rasika Dilip Rajebhosale', '1000000052', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'rasika.rajebhosale@aangan.com', '1000000052', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-102', '3705ae4f-2fdc-493d-972d-c76865398002', 1, 500, 'Vaibhav Nagesh Jadhav')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Vaibhav Nagesh Jadhav', '1000000053', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'vaibhav.jadhav@aangan.com', '1000000053', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-103', '3705ae4f-2fdc-493d-972d-c76865398002', 1, 500, 'Rajeev H. Kolte')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Rajeev H. Kolte', '9869868687', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'rajeev.kolte@aangan.com', '9869868687', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-201', '3705ae4f-2fdc-493d-972d-c76865398002', 2, 500, 'Dilip Baburao Rajebhosale')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Dilip Baburao Rajebhosale', '1000000054', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'dilip.rajebhosale@aangan.com', '1000000054', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-202', '3705ae4f-2fdc-493d-972d-c76865398002', 2, 500, 'Shrikant Dattaram Patil')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Shrikant Dattaram Patil', '1000000055', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'shrikant.patil@aangan.com', '1000000055', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-203', '3705ae4f-2fdc-493d-972d-c76865398002', 2, 500, 'Bhairavi Bhalchandra Dalvi')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Bhairavi Bhalchandra Dalvi', '9819265192', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'bhairavi.dalvi@aangan.com', '9819265192', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-301', '3705ae4f-2fdc-493d-972d-c76865398002', 3, 500, 'Manohar Sharad Shirke')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Manohar Sharad Shirke', '1000000056', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'manohar.shirke@aangan.com', '1000000056', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-302', '3705ae4f-2fdc-493d-972d-c76865398002', 3, 500, 'Bhalchandra Ramchandra Dalvi')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Bhalchandra Ramchandra Dalvi', '1000000057', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'bhalchandra.dalvi@aangan.com', '1000000057', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-303', '3705ae4f-2fdc-493d-972d-c76865398002', 3, 500, 'K. P. Sitaram')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'K. P. Sitaram', '1000000058', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'k.sitaram@aangan.com', '1000000058', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-401', '3705ae4f-2fdc-493d-972d-c76865398002', 4, 500, 'Vilas Sakharam Sawant')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Vilas Sakharam Sawant', '9820480881', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'vilas.sawant@aangan.com', '9820480881', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-402', '3705ae4f-2fdc-493d-972d-c76865398002', 4, 500, 'Shridhar Shivram Talekar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Shridhar Shivram Talekar', '1000000059', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'shridhar.talekar@aangan.com', '1000000059', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E-403', '3705ae4f-2fdc-493d-972d-c76865398002', 4, 500, 'Vilas Balkrishna Mote')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Vilas Balkrishna Mote', '1000000060', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'vilas.mote@aangan.com', '1000000060', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'E1-101', '3559918b-e600-447e-9ff4-573c52697c0d', 1, 500, 'Ganesh Patil')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Ganesh Patil', '9930668736', 'ganesh.patil.31@gmail.com', v_flat_id, 'ADMIN', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'ganesh.patil.31@gmail.com', '9930668736', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-101', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 1, 500, 'Pradeep Ram. Kanojia')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Pradeep Ram. Kanojia', '1000000061', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'pradeep.kanojia@aangan.com', '1000000061', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-102', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 1, 500, 'Kishor Shantaram Bane')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Kishor Shantaram Bane', '1000000062', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'kishor.bane@aangan.com', '1000000062', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-103', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 1, 500, 'Ashok Atmaram Girkar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Ashok Atmaram Girkar', '1000000063', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'ashok.girkar@aangan.com', '1000000063', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-104', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 1, 500, 'Vasant Shankar Shetty')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Vasant Shankar Shetty', '1000000064', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'vasant.shetty@aangan.com', '1000000064', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-201', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 2, 500, 'Haribhau Bapu Girhe')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Haribhau Bapu Girhe', '1000000065', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'haribhau.girhe@aangan.com', '1000000065', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-202', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 2, 500, 'Arun Sitaram Nikam')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Arun Sitaram Nikam', '1000000066', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'arun.nikam@aangan.com', '1000000066', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-203', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 2, 500, 'Haribhau Shankar Chavhan')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Haribhau Shankar Chavhan', '1000000067', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'haribhau.chavhan@aangan.com', '1000000067', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-204', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 2, 500, 'Hanmant Shankar Jagtap')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Hanmant Shankar Jagtap', '8104792828', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'hanmant.jagtap@aangan.com', '8104792828', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-301', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 3, 500, 'Sadanand Bhujang Rane')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Sadanand Bhujang Rane', '1000000068', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'sadanand.rane@aangan.com', '1000000068', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-302', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 3, 500, 'Bhaskar Damodar Mokal')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Bhaskar Damodar Mokal', '1000000069', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'bhaskar.mokal@aangan.com', '1000000069', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-303', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 3, 500, 'Buva G. Pujari')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Buva G. Pujari', '1000000070', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'buva.pujari@aangan.com', '1000000070', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-304', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 3, 500, 'Leela Dnyanoba Hakare')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Leela Dnyanoba Hakare', '1000000071', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'leela.hakare@aangan.com', '1000000071', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-401', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 4, 500, 'Dipak Shripat Chavhan')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Dipak Shripat Chavhan', '1000000072', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'dipak.chavhan@aangan.com', '1000000072', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-402', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 4, 500, 'Prakash Jayram Dalvi')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Prakash Jayram Dalvi', '9619036944', '', v_flat_id, 'ADMIN', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'prakash.dalvi@aangan.com', '9619036944', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-403', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 4, 500, 'Ashok Baba Parab')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Ashok Baba Parab', '1000000073', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'ashok.parab@aangan.com', '1000000073', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

DO $$
DECLARE v_flat_id UUID; v_member_id UUID; v_user_id UUID;
BEGIN
  INSERT INTO flats (id, flat_number, wing_id, floor, area_sqft, owner_name)
  VALUES (gen_random_uuid(), 'F-404', '809ee6a9-9fd4-46af-a3de-5e486e12ae9c', 4, 500, 'Anita A. Shelar')
  RETURNING id INTO v_flat_id;
  INSERT INTO members (id, name, mobile, email, flat_id, role, designation, is_registered, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'Anita A. Shelar', '1000000074', '', v_flat_id, 'MEMBER', '', true, true, NOW(), NOW())
  RETURNING id INTO v_member_id;
  INSERT INTO users (id, email, mobile, password_hash, member_id, is_active, created_at, updated_at)
  VALUES (gen_random_uuid(), 'anita.shelar@aangan.com', '1000000074', '$2b$10$1GRI4rObbFI8B/DjLi49TOnNo58d4BKI46aBOl3uA6N9/V1PIA6Iy', v_member_id, true, NOW(), NOW())
  RETURNING id INTO v_user_id;
  UPDATE members SET user_id = v_user_id, registered_at = NOW() WHERE id = v_member_id;
END $$;

COMMIT;
SELECT 'flats' AS tbl, COUNT(*) FROM flats UNION ALL SELECT 'members', COUNT(*) FROM members UNION ALL SELECT 'users', COUNT(*) FROM users;