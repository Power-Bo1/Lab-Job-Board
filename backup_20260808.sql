--
-- PostgreSQL database dump
--

\restrict qjUldEolYihR850djbBgOVVMfW0FDiYitUHWCEf1j8IZUspBtCeHUUh9p8NcnJU

-- Dumped from database version 16.14
-- Dumped by pg_dump version 16.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.applications DROP CONSTRAINT IF EXISTS applications_job_id_fkey;
DROP INDEX IF EXISTS public.idx_applications_status;
DROP INDEX IF EXISTS public.idx_applications_job_id;
ALTER TABLE IF EXISTS ONLY public.jobs DROP CONSTRAINT IF EXISTS jobs_pkey;
ALTER TABLE IF EXISTS ONLY public.applications DROP CONSTRAINT IF EXISTS applications_pkey;
DROP TABLE IF EXISTS public.jobs;
DROP TABLE IF EXISTS public.applications;
SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: applications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.applications (
    id uuid NOT NULL,
    job_id character varying(255) NOT NULL,
    applicant_name character varying(200) NOT NULL,
    applicant_email character varying(200) NOT NULL,
    cover_letter text,
    status character varying(50) DEFAULT 'pending'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT applications_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'reviewed'::character varying, 'accepted'::character varying, 'rejected'::character varying])::text[])))
);


ALTER TABLE public.applications OWNER TO postgres;

--
-- Name: jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.jobs (
    id character varying(255) NOT NULL,
    title character varying(200) NOT NULL,
    description text NOT NULL,
    company character varying(200) NOT NULL,
    location character varying(200) NOT NULL,
    salary_range character varying(100),
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.jobs OWNER TO postgres;

--
-- Data for Name: applications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.applications (id, job_id, applicant_name, applicant_email, cover_letter, status, created_at) FROM stdin;
4f498543-2e93-4a9b-98dc-77041fe7c9c5	bfb6ac22-926e-4c90-be8c-727852f4f67b	Bob	BOB@gmail.com	I'm the best of the best	pending	2026-08-03 19:08:54.464228
\.


--
-- Data for Name: jobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.jobs (id, title, description, company, location, salary_range, created_at) FROM stdin;
job-001	Senior DevOps Engineer	We are looking for an experienced DevOps engineer to design, implement and maintain our cloud infrastructure. You will work with Kubernetes, Terraform, and CI/CD pipelines to ensure high availability and scalability of our platform.	TechCorp Ltd.	Remote	$120,000 – $160,000	2026-08-02 13:41:44.307688+00
job-002	Backend Developer (Python)	Join our growing team as a backend developer. You will build and maintain RESTful APIs using Python and FastAPI, design PostgreSQL schemas, and collaborate with frontend engineers to deliver new product features.	StartupXYZ	Tel Aviv, Israel	$90,000 – $120,000	2026-08-02 13:41:44.307688+00
job-003	Cloud Architect	Design and implement cloud-native solutions across AWS and GCP. Lead architecture reviews, mentor junior engineers, and drive the adoption of Infrastructure as Code using Terraform and Pulumi.	CloudSystems Inc.	Hybrid – Berlin, Germany	$140,000 – $180,000	2026-08-02 13:41:44.307688+00
job-004	Frontend Engineer (React)	Build beautiful, performant web applications using React, TypeScript and modern tooling. You will work closely with our UX team to translate designs into pixel-perfect, accessible components.	ProductLab	Remote	$80,000 – $110,000	2026-08-02 13:41:44.307688+00
job-005	Security Engineer (DevSecOps)	Own the security posture of our engineering organisation. Integrate SAST/DAST tools into CI/CD, run threat-modelling sessions, and respond to security incidents. Experience with OWASP Top 10 is required.	SecureOps	London, UK	$130,000 – $165,000	2026-08-02 13:41:44.307688+00
bfb6ac22-926e-4c90-be8c-727852f4f67b	Junior DevOps Engineer	Relevant education in the field.\nAt least 3 years of experience in implementing or administering enterprise information systems.\nAt least 2 years of experience working with Azure DevOps or Monday.com, including user management, permissions, and system configuration.\nExperience working with business users, including requirements analysis, solution implementation, and user training.\nExperience working with external vendors, handling incidents, and leading improvement processes.\nAbility to analyze and implement processes at the functional level.\nCertifications or training in Azure DevOps or Monday – significant advantage.\nFamiliarity with organizational project, task, and portfolio management 	Yteach	Tel aviv	$50k - $100k	2026-08-03 19:06:54.206306+00
bd6ec987-6252-435a-a34c-c1d519530c04	Persistence Test	survives down/up	TestCo	Remote	$1	2026-08-08 17:42:45.387213+00
\.


--
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: idx_applications_job_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_applications_job_id ON public.applications USING btree (job_id);


--
-- Name: idx_applications_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_applications_status ON public.applications USING btree (status);


--
-- Name: applications applications_job_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.jobs(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict qjUldEolYihR850djbBgOVVMfW0FDiYitUHWCEf1j8IZUspBtCeHUUh9p8NcnJU

