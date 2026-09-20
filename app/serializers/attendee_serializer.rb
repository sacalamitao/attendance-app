module AttendeeSerializer
  module_function

  def call(attendee, reference_date: Date.current)
    ministry = attendee.ministry_on(reference_date)
    {
      id: attendee.id,
      full_name: attendee.full_name,
      gender: attendee.gender,
      birthdate: attendee.birthdate,
      age: attendee.age(on: reference_date),
      ministry_classification: ministry,
      ministry_label: ministry && Ministry.label(ministry),
      active: attendee.active?,
      deactivated_at: attendee.deactivated_at,
      created_at: attendee.created_at,
      updated_at: attendee.updated_at
    }
  end
end
