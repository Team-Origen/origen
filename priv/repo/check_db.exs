alias Origen.Repo
alias Origen.Patients.{Persona, PatientProfile}

IO.puts("
=== PERSONAS REGISTRADAS ===")
for p <- Repo.all(Persona) do
  IO.puts("ID: #{p.id} | #{p.first_name} #{p.last_name} | #{p.document_type}: #{p.document_number}")
end

IO.puts("
=== PERFILES DE PACIENTES ===")
for pr <- Repo.all(PatientProfile) do
  IO.puts("Email: #{pr.email} | Estado: #{pr.state} | Persona ID: #{inspect(pr.persona_id)} | Tel. Verificado: #{pr.phone_verified}")
end
IO.puts("")
