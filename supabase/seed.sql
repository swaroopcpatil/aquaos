-- AquaOS SAMPLE seed data. Everything here is fictional placeholder data:
-- names are prefixed "SAMPLE", products are is_sample = true / unverified, and no manufacturer names,
-- model numbers or pump curves are invented. No pump_curves rows are seeded on purpose.
-- Profiles/memberships are not seeded because they need auth.users rows; create users via Supabase Auth.

insert into public.organizations (id, name, slug) values
  ('00000000-0000-4000-8000-000000000001', 'SAMPLE Organization', 'sample-org');

insert into public.customers (id, organization_id, name, phone, village, notes) values
  ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001', 'SAMPLE Customer One', '000-000-0001', 'SAMPLE Village', 'SAMPLE data'),
  ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000001', 'SAMPLE Customer Two', '000-000-0002', 'SAMPLE Village', 'SAMPLE data');

insert into public.farms (id, organization_id, customer_id, name, area_acres, crop) values
  ('00000000-0000-4000-8000-000000000021', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000011', 'SAMPLE Farm A', 2.5, 'SAMPLE crop'),
  ('00000000-0000-4000-8000-000000000022', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000012', 'SAMPLE Farm B', 4.0, 'SAMPLE crop');

insert into public.borewells (id, organization_id, farm_id, name, depth_m, static_water_level_m, pumping_water_level_m, casing_diameter_mm) values
  ('00000000-0000-4000-8000-000000000031', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000021', 'SAMPLE Borewell 1', 100, 30, 45, 150),
  ('00000000-0000-4000-8000-000000000032', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000022', 'SAMPLE Borewell 2', 80, 20, 35, 150);

insert into public.products (id, organization_id, name, category, manufacturer, model, is_sample, verification_status, source_type, source_reference) values
  ('00000000-0000-4000-8000-000000000041', '00000000-0000-4000-8000-000000000001', 'SAMPLE Pump Product A', 'pump', 'SAMPLE Manufacturer', 'SAMPLE-MODEL-A', true, 'unverified', 'sample', 'SAMPLE - not a real catalogue entry'),
  ('00000000-0000-4000-8000-000000000042', '00000000-0000-4000-8000-000000000001', 'SAMPLE Pump Product B', 'pump', 'SAMPLE Manufacturer', 'SAMPLE-MODEL-B', true, 'unverified', 'sample', 'SAMPLE - not a real catalogue entry');

insert into public.installations (id, organization_id, customer_id, farm_id, borewell_id, product_id, status, notes) values
  ('00000000-0000-4000-8000-000000000051', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000021', '00000000-0000-4000-8000-000000000031', '00000000-0000-4000-8000-000000000041', 'active', 'SAMPLE installation');

insert into public.service_tickets (id, organization_id, customer_id, installation_id, title, description) values
  ('00000000-0000-4000-8000-000000000061', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000051', 'SAMPLE ticket: low flow', 'SAMPLE data');
